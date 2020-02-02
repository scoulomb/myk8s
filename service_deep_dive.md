# Service deep dive

## Clean up
```
k delete svc,deployment --all
k create deployment deploy1 --image=nginx
```

## Each pod has an IP

````
vagrant@k8sMaster:~$ ip a | grep inet
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic eth0

vagrant@k8sMaster:~$ k get pods -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE        NOMINATED NODE   READINESS GATES
deploy1-5d98f66655-8gffz   1/1     Running   0          72s   192.168.16.171   k8smaster   <none>

export POD_NAME=$(k get pods -o wide | grep "deploy1-" |  awk '{ print $1 }')
export POD_IP=$(k get pods -o wide | grep "deploy1-" |  awk '{ print $6 }')
```

We can target pod ip

```
vagrant@k8sMaster:~$  curl --silent http://$POD_IP | grep "<title>"
<title>Welcome to nginx!</title>
```
## Use service

Rather than targetting pod directy we can use service

```
vagrant@k8sMaster:~$ k describe pod $POD_NAME | grep -A 1 "Labels"
Labels:       app=deploy1
              pod-template-hash=5d98f66655


vagrant@k8sMaster:~$ k expose deployment deploy1 --port=80 --type=ClusterIP --dry-run -o yaml | grep -A 2 "selector"
  selector:
    app: deploy1
  type: ClusterIP

k expose deployment deploy1 --port=80 --type=ClusterIP 

````
Pod is linked to a service via a label in selctor

We can use service to traget the pod 

```
vagrant@k8sMaster:~$ k get svc
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
deploy1      ClusterIP   10.100.200.199   <none>        80/TCP    5s


vagrant@k8sMaster:~$ export CLUSTER_IP=$(k get svc | grep "deploy1" |  awk '{ print $3 }')
vagrant@k8sMaster:~$ echo $CLUSTER_IP
10.100.200.199

vagrant@k8sMaster:~$ curl --silent http://$CLUSTER_IP | grep "<title>"
<title>Welcome to nginx!</title>

````

Endpoint controller created corresponding endpoints:
https://github.com/kubernetes/kubernetes/blob/master/pkg/controller/endpoint/endpoints_controller.go#L200

```
vagrant@k8sMaster:~$ k get ep | grep "deploy1"
deploy1      192.168.16.171:80   3m33s
````

When sacling deployment, it creates other ep and load balance the traffic

```
k scale --replicas=3 deployment/deploy1

vagrant@k8sMaster:~$ k get pods -o wide | grep "deploy1-"
deploy1-5d98f66655-8gffz   1/1     Running   0          22m   192.168.16.171   k8smaster   <none>
        <none>
deploy1-5d98f66655-qnr5s   1/1     Running   0          26s   192.168.16.173   k8smaster   <none>
        <none>
deploy1-5d98f66655-skf26   1/1     Running   0          26s   192.168.16.172   k8smaster   <none>
        <none>

vagrant@k8sMaster:~$ k get ep | grep "deploy1"
deploy1      192.168.16.171:80,192.168.16.172:80,192.168.16.173:80   5m5s

```

## Service internal

kube-proxy watches endpoint and service updates iptable

Check it is up

````
vagrant@k8sMaster:~$ k -n kube-system logs kube-proxy-wkxs6
W0202 11:39:49.644676       1 server_others.go:329] Flag proxy-mode="" unknown, assuming iptables proxy
```


https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/#iptables
We can see updated iptable !

````
vagrant@k8sMaster:~$ sudo iptables-save | grep  10.100.200.199
-A KUBE-SERVICES ! -s 192.168.0.0/16 -d 10.100.200.199/32 -p tcp -m comment --comment "default/deploy1: cluster IP" -m tcp --dport 80 -j KUBE-MARK-MASQ
-A KUBE-SERVICES -d 10.100.200.199/32 -p tcp -m comment --comment "default/deploy1: cluster IP" -m tcp --dport 80 -j KUBE-SVC-HFJG5QJDKA2NKYX2

vagrant@k8sMaster:~$ sudo iptables-save | grep  KUBE-SVC-HFJG5QJDKA2NKYX2
:KUBE-SVC-HFJG5QJDKA2NKYX2 - [0:0]
-A KUBE-SERVICES -d 10.100.200.199/32 -p tcp -m comment --comment "default/deploy1: cluster IP" -m tcp --dport 80 -j KUBE-SVC-HFJG5QJDKA2NKYX2
-A KUBE-SVC-HFJG5QJDKA2NKYX2 -m statistic --mode random --probability 0.33332999982 -j KUBE-SEP-IVTV3JKMDAKRFCBH
-A KUBE-SVC-HFJG5QJDKA2NKYX2 -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-PFJDNPXONEKPWG5A
-A KUBE-SVC-HFJG5QJDKA2NKYX2 -j KUBE-SEP-SIUA6YONSJ3WPF22

vagrant@k8sMaster:~$ sudo iptables-save | grep 192.168.16.17
-A KUBE-SEP-IVTV3JKMDAKRFCBH -s 192.168.16.171/32 -j KUBE-MARK-MASQ
-A KUBE-SEP-IVTV3JKMDAKRFCBH -p tcp -m tcp -j DNAT --to-destination 192.168.16.171:80
-A KUBE-SEP-PFJDNPXONEKPWG5A -s 192.168.16.172/32 -j KUBE-MARK-MASQ
-A KUBE-SEP-PFJDNPXONEKPWG5A -p tcp -m tcp -j DNAT --to-destination 192.168.16.172:80
-A KUBE-SEP-SIUA6YONSJ3WPF22 -s 192.168.16.173/32 -j KUBE-MARK-MASQ
-A KUBE-SEP-SIUA6YONSJ3WPF22 -p tcp -m tcp -j DNAT --to-destination 192.168.16.173:80
````


## Svc discovery by env var or DNS by another pod

````
vagrant@k8sMaster:~$ k get svc
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
deploy1      ClusterIP   10.100.200.199   <none>        80/TCP    47m
````
Create a client pod `deploy-test` to target niginx service

````
k create deployment deploy-test --image=nginx
k exec -it deploy-test-854bc66d47-tptt9 -- /bin/bash
# apt-get update
# apt-get install curl
root@deploy-test-854bc66d47-tptt9:/# env | grep DEPLOY1_
DEPLOY1_PORT=tcp://10.100.200.199:80
DEPLOY1_PORT_80_TCP=tcp://10.100.200.199:80
DEPLOY1_PORT_80_TCP_PORT=80
DEPLOY1_SERVICE_HOST=10.100.200.199
DEPLOY1_SERVICE_PORT=80
DEPLOY1_PORT_80_TCP_PROTO=tcp
DEPLOY1_PORT_80_TCP_ADDR=10.100.200.199
root@deploy-test-854bc66d47-tptt9:/# curl --silent $DEPLOY1_SERVICE_HOST:$DEPLOY1_SERVICE_PORT | grep "<title>"
<title>Welcome to nginx!</title>
root@deploy-test-854bc66d47-tptt9:/# curl --silent deploy1 |  grep "<title>"
<title>Welcome to nginx!</title>
root@deploy-test-854bc66d47-tptt9:/#
````
Why service discvery by env var is dangerous


If now I delete the service and recreate the service

````
k delete svc deploy1
k expose deployment deploy1 --port=80 --type=ClusterIP 

vagrant@k8sMaster:~$ k get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
deploy1      ClusterIP   10.96.121.165   <none>        80/TCP    7s
````

Cluster IP has changed from 10.100.200.199 to 10.96.121.165

Thus
 
````
vagrant@k8sMaster:~$ k exec -it deploy-test-854bc66d47-tptt9 -- /bin/bash
root@deploy-test-854bc66d47-tptt9:/# root@deploy-test-854bc66d47-tptt9:/# curl --max-time 10 $DEPLOY1_SERVICE_HOST:$DEPLOY1_SERVICE_PORT | grep "<title>"
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:10 --:--:--     0
curl: (28) Connection timed out after 10001 milliseconds
root@deploy-test-854bc66d47-tptt9:/# curl --silent --max-time 10 deploy1 | grep "<title>"
<title>Welcome to nginx!</title>
````

If I scale the client 

````
k scale --replicas=3 deployment/deploy-test
root@deploy-test-854bc66d47-tptt9:/# echo $DEPLOY1_SERVICE_HOST
10.100.200.199
root@deploy-test-854bc66d47-rfhmt:/# echo $DEPLOY1_SERVICE_HOST
10.96.121.165
````

Only new pods have the new IP (if service created after pod creation it does not kn
ow it). So env var discovery forces to expose service before deploying client pod

## Within a container

It is also possible to target a service inside a container

```
vagrant@k8sMaster:~$ k exec -it deploy-test-854bc66d47-tptt9 -- /bin/bash
root@deploy-test-854bc66d47-tptt9:/#  curl --silent 127.0.0.1 | grep "<title>"
<title>Welcome to nginx!</title>
````
## use a different port 

```
k delete svc deploy1
k expose deployment deploy1 --port=5000 --target-port=80 --type=ClusterIP
````

otherwiswe by default port = target port
Then 

```
vagrant@k8sMaster:~$ k get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
deploy1      ClusterIP   10.103.100.13   <none>        5000/TCP   2m9s

vagrant@k8sMaster:~$ curl --silent 10.103.100.13:5000 | grep "<title>"
<title>Welcome to nginx!</title>
````
target-port can be a "named port"
https://kubernetes.io/docs/concepts/services-networking/service/#defining-a-service
So different pod could use a different port (not tested)


## Other type of service

### NodePort

NodePort is a simple connection from a high-port routed to a ClusterIP 
The NodePort is accessible via calls to <NodeIP>:<NodePort>.

To ensure NodePort is in the range of port forwarded by the VM, we will add following lines
in command section of kube-apiserver.yaml
````
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
--service-node-port-range=20000-22767
```

This will restart api-server (see 24s)

````
vagrant@k8sMaster:~$  kubectl get pods -n kube-system
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-6b9d4c8765-f988d   1/1     Running   3          3d5h
calico-node-z4hzv                          1/1     Running   3          3d5h
coredns-5644d7b6d9-5djh9                   1/1     Running   3          3d5h
coredns-5644d7b6d9-xp79t                   1/1     Running   3          3d5h
etcd-k8smaster                             1/1     Running   3          3d5h
kube-apiserver-k8smaster                   1/1     Running   0          24s
````

````
k delete svc deploy1
vagrant@k8sMaster:~$ k expose deployment deploy1 --port=80 --type=NodePort
service/deploy1 exposed
vagrant@k8sMaster:~$ k get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
deploy1      NodePort    10.97.110.238   <none>        80:32000/TCP   7s
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP        3h3m
vagrant@k8sMaster:~$
````

Thus we can now target this svc as cluster ip, but also using node ip

````
# From master node
vagrant@k8sMaster:~$ curl --silent 10.0.2.15:32000 | grep "<title>"
<title>Welcome to nginx!</title>
vagrant@k8sMaster:~$ curl --silent 127.0.0.1:32000 | grep "<title>"
<title>Welcome to nginx!</title>
vagrant@k8sMaster:~$ curl --silent 127.0.0.1:32001 | grep "<title>"

# Machine host (windows and port forwarding)
# k8sMaster.vm.network "forwarded_port", guest: 32000, host: 32000, auto_correct: true
scoulombel@XXXXX MINGW64 ~
$ curl --silent 127.0.0.1:32000 | grep  "<title>"
<title>Welcome to nginx!</title>

````
### LoadBalancer

Creating a LoadBalancer service generates a NodePort.
It sends an asynchronous call to an external load balancer, 
Usually one of a cloud provider. 
The External-IP value will remain in a <Pending> state until the load balancer returns. 
It is only used to load balancer inside a PAAS. 

````
k delete svc deploy1
k expose deployment deploy1 --port=80 --type=LoadBalancer
````

Note the pending and the fact it behave as cluster ip

````
vagrant@k8sMaster:~$ k get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
deploy1      LoadBalancer   10.111.52.75   <pending>     80:32000/TCP   15s
kubernetes   ClusterIP      10.96.0.1      <none>        443/TCP        3h13m
vagrant@k8sMaster:~$ curl --silent 10.111.52.75 | grep "<title>"
<title>Welcome to nginx!</title>

````

### ExternalName

````
apiVersion: v1
kind: Service
metadata:
  name: my-ext-svc
spec:
  type: ExternalName
  externalName: www.mozilla.org
  
k apply -f my-ext-svc.yaml
````

Then use it

````
vagrant@k8sMaster:~$ k get svc
NAME         TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)        AGE
deploy1      LoadBalancer   10.111.52.75   <pending>         80:32000/TCP   9m9s
kubernetes   ClusterIP      10.96.0.1      <none>            443/TCP        3h22m
my-ext-svc   ExternalName   <none>         www.mozilla.org   <none>         4m19s
vagrant@k8sMaster:~$ k exec -it deploy-test-854bc66d47-tptt9 -- /bin/sh
# curl my-ext-svc
<!DOCTYPE html>
````

### Service wihtout a selector

Controller when there is label creates endpoint
But can define it manually in particular to target outside ressource

````
vagrant@k8sMaster:~$ nslookup google.fr
Name:   google.fr
Address: 216.58.207.131

vagrant@k8sMaster:~$ nslookup github.com
Non-authoritative answer:
Name:   github.com
Address: 140.82.118.4

echo '
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ports:
    - protocol: TCP
      port: 443
      targetPort: 443
' >> svc-no-sel.yaml
echo '
apiVersion: v1
kind: Endpoints
metadata:
  name: my-service
subsets:
  - addresses:
      - ip: 216.58.207.131
      - ip: 140.82.118.4
    ports:
      - port: 443
' >> ep-no-sel.yaml

k apply -f svc-no-sel.yaml 
k apply -f ep-no-sel.yaml
````

So that

````
vagrant@k8sMaster:~$ k describe svc my-service | grep Endpoints
Endpoints:         140.82.118.4:443,216.58.207.131:443
````
This time I have a cluster ip (node service name DNS only usable from within a pod)

````
vagrant@k8sMaster:~$ k get svc | grep my
my-ext-svc   ExternalName   <none>         www.mozilla.org   <none>         46m
my-service   ClusterIP      10.99.12.62    <none>            443/TCP        30m

vagrant@k8sMaster:~$ curl -k https://10.99.12.62 -v 

Either
< location: http://www.google.com/
< Location: https://github.com/

````

## Ingresses

Here can start from new deployment + svc
mix nodeport and cluser ip
then join with deep dive


check ex 7,2
