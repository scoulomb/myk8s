# Service deep dive

## Clean up

```
k delete svc,deployment --all
k create deployment deploy1 --image=nginx
```

## Each pod has an IP

```
vagrant@k8sMaster:~$ ip a | grep inet
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic eth0

vagrant@k8sMaster:~$ k get pods -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE        NOMINATED NODE   READINESS GATES
deploy1-5d98f66655-8gffz   1/1     Running   0          72s   192.168.16.171   k8smaster   <none>

```

We will export `POD_NAME` and `POD_IP`.

```
export POD_NAME=$(k get pods -o wide | grep "deploy1-" |  awk '{ print $1 }')
export POD_IP=$(k get pods -o wide | grep "deploy1-" |  awk '{ print $6 }')
```

We can target pod ip directly

```
vagrant@k8sMaster:~$  curl --silent http://$POD_IP | grep "<title>"
<title>Welcome to nginx!</title>
```

## Use service

Rather than targetting pod directy we can use service
Pod is linked to a service via a label in selector as it can be shown here:

```
vagrant@k8sMaster:~$ k describe pod $POD_NAME | grep -A 1 "Labels"
Labels:       app=deploy1
              pod-template-hash=5d98f66655


vagrant@k8sMaster:~$ k expose deployment deploy1 --port=80 --type=ClusterIP --dry-run -o yaml | grep -A 2 "selector"
  selector:
    app: deploy1
  type: ClusterIP

k expose deployment deploy1 --port=80 --type=ClusterIP 

```

We can use service to target the pod using the cluster ip.

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

This is possible because from [k8s doc](from: https://kubernetes.io/docs/concepts/services-networking/service/)
> The controller for the Service selector continuously scans for Pods that match its selector, and then POSTs any updates to an Endpoint object also named “my-service”.

```
vagrant@k8sMaster:~$ k get ep | grep "deploy1"
deploy1      192.168.16.171:80   3m33s
````

When scaling deployment, it creates other ep and load balance the traffic
We scale by doing `k scale --replicas=3 deployment/deploy1`


And check new endpoints

```
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

`kube-proxy` watches endpoints and services to updates iptable and thus redirect to correct pod.

It has several [modes](https://kubernetes.io/docs/concepts/services-networking/service/#virtual-ips-and-service-proxies)
- user space proxy
- ip table proxy :update ip table based on service cluster ip (virtual server) and endpoints (pool members)
- ipvs (netlinks)

We use below ip table.

It is running inside a Pod

````
vagrant@k8sMaster:~$ k -n kube-system logs kube-proxy-wkxs6
W0202 11:39:49.644676       1 server_others.go:329] Flag proxy-mode="" unknown, assuming iptables proxy
````


We can see updated iptable ! as documented in [doc](https://kubernetes.io/docs/tasks/debug-application-cluster/debug-service/#iptables)

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

## Svc discovery by environment variable or DNS within a POD

````
vagrant@k8sMaster:~$ k get svc
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
deploy1      ClusterIP   10.100.200.199   <none>        80/TCP    47m
````

Create a client pod `deploy-test` to target nginx service previously created (also using nginx image)
In snippet below, within a container in that pod we do:
- service discovery by environment var
- Followed by [DNS](https://kubernetes.io/docs/concepts/services-networking/service/#dns). DNS is pointing to `cluster ip`.

````
k create deployment deploy-test --image=nginx
k exec -it deploy-test-854bc66d47-tptt9 -- /bin/bash
root@deploy-test-854bc66d47-tptt9:/# apt-get update
root@deploy-test-854bc66d47-tptt9:/# apt-get install curl
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

Why service discovery by env var is dangerous?

If now I delete the service and recreate the service

````
k delete svc deploy1
k expose deployment deploy1 --port=80 --type=ClusterIP 

vagrant@k8sMaster:~$ k get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
deploy1      ClusterIP   10.96.121.165   <none>        80/TCP    7s
````

Cluster IP has changed from `10.100.200.199` to `10.96.121.165`

Thus service discovery by environment var stop working, while DNS one is working
 
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

Only new pods have the new IP (if service created after pod creation it does not know it). So env var discovery forces to expose service before deploying client pod
This ordering issue is documented here: https://kubernetes.io/docs/concepts/services-networking/service/#discovering-services
> When you have a Pod that needs to access a Service, and you are using the environment variable method to publish the port and cluster IP to the client Pods, you must create the Service before the client Pods come into existence. Otherwise, those client Pods won’t have their environment variables populated.

If we modify the service a redeployment is needed. 

It is even said: "You can (and almost always should) set up a DNS service for your Kubernetes cluster using an add-on."

Eventually service DNS name can templatized using Helm values (or OpenShift template parameters)
and used as environment variable 

## Within a container

It is also possible to target a service inside a container

```
vagrant@k8sMaster:~$ k exec -it deploy-test-854bc66d47-tptt9 -- /bin/bash
root@deploy-test-854bc66d47-tptt9:/#  curl --silent 127.0.0.1 | grep "<title>"
<title>Welcome to nginx!</title>
````
## Use a different port 

```
k delete svc deploy1
k expose deployment deploy1 --port=5000 --target-port=80 --type=ClusterIP
````

otherwiswe by default `port = target port`
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

To ensure NodePort is in the range of port forwarded by the VM, we will add [following line](http://www.thinkcode.se/blog/2019/02/20/kubernetes-service-node-port-range) `--service-node-port-range=32000-32000` in command section of `/etc/kubernetes/manifests/kube-apiserver.yaml`

This will restart api-server (see 24s in command below).

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

Alternative is to specify the `NodePort` directly:
https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.17/#servicespec-v1-core
> `nodePort:Integer`: The port on each node on which this service is exposed when type=NodePort or LoadBalancer. Usually assigned by the system. If specified, it will be allocated to the service if unused or else creation of the service will fail. Default is to auto-allocate a port if the ServiceType of this Service requires one. More info: https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport


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

````
We can target outside from the VM.
This is equivalent to target ip address of the node from the outside

This is working because of port forwarding define in Vagrant file as follows:
`k8sMaster.vm.network "forwarded_port", guest: 32000, host: 32000, auto_correct: true`

Output is:
````
scoulomb@XXXXX MINGW64 ~
$ curl --silent 127.0.0.1:32000 | grep  "<title>"
<title>Welcome to nginx!</title>
````
### LoadBalancer
Doc: https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/

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

Note external name does not have cluster ip, and external ip is replacing the virtual ip
It does not have env var
So usable only inside a pod using DNS disovery


### Service without a selector

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
This time I have a cluster ip 

````
vagrant@k8sMaster:~$ k get svc | grep my
my-ext-svc   ExternalName   <none>         www.mozilla.org   <none>         46m
my-service   ClusterIP      10.99.12.62    <none>            443/TCP        30m

vagrant@k8sMaster:~$ curl -k https://10.99.12.62 -v 

Either
< location: http://www.google.com/
< Location: https://github.com/

````
----
# Ingresses

## Setup

We will do 2 deployments with 3 replicas.
We will change title tag in file `/usr/share/nginx/html/index.html`
deployment1-replica{1..3} and deployment2-rep{1..3}

### Create deployments and services

```
k delete svc,deployment --all
k create deployment deploy1 --image=nginx
k create deployment deploy2 --image=nginx
k scale --replicas=3 deployment/deploy1
k scale --replicas=3 deployment/deploy2
k expose deployment deploy1 --port=80 --type=ClusterIP 
k expose deployment deploy2 --port=80 --type=NodePort 
```

### Personalize the index

````
for pod in $(k get pods | grep deploy |  awk '{ print $1 }')
do
   echo "processing pod $pod"
   rm -f index.html
   echo $pod > index.html
   cat index.html
   kubectl cp index.html $pod:/usr/share/nginx/html/index.html
   rm -f index.html
done
````

And can curl as usual  with node port or not

```
vagrant@k8sMaster:~$ k get ReplicaSet
NAME                 DESIRED   CURRENT   READY   AGE
deploy1-5d98f66655   3         3         3       5m57s
deploy2-5ff54b6b7b   3         3         3       5m57s

vagrant@k8sMaster:~$ k get pods
NAME                       READY   STATUS    RESTARTS   AGE
deploy1-5d98f66655-d8np4   1/1     Running   0          4m7s
deploy1-5d98f66655-gqgdq   1/1     Running   0          4m7s
deploy1-5d98f66655-pgrdl   1/1     Running   0          4m8s
deploy2-5ff54b6b7b-94kbj   1/1     Running   0          4m8s
deploy2-5ff54b6b7b-npnsh   1/1     Running   0          4m7s
deploy2-5ff54b6b7b-z7fgp   1/1     Running   0          4m7s
vagrant@k8sMaster:~$ k get svc
NAME         TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
deploy1      ClusterIP   10.98.74.125   <none>        80/TCP         4m11s
deploy2      NodePort    10.107.92.16   <none>        80:32000/TCP   4m9s
kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP        4m4s

vagrant@k8sMaster:~$ curl 10.98.74.125
deploy1-5d98f66655-d8np4
vagrant@k8sMaster:~$ curl 10.98.74.125
deploy1-5d98f66655-pgrdl
vagrant@k8sMaster:~$ curl 10.107.92.16
deploy2-5ff54b6b7b-npnsh
vagrant@k8sMaster:~$ curl 10.107.92.16
deploy2-5ff54b6b7b-94kbj
vagrant@k8sMaster:~$ curl 127.0.0.1:32000
deploy2-5ff54b6b7b-94kbj
```

We can see first part of pod name is rc name

## Set rbac for ingress controller

Eventually do `k delete -f` before.
````
vagrant@k8sMaster:~$ cat ingress.rbac.yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: kube-system
vagrant@k8sMaster:~$
````
then 


````
vagrant@k8sMaster:~$ k apply -f ingress.rbac.yaml
clusterrole.rbac.authorization.k8s.io/traefik-ingress-controller created
clusterrolebinding.rbac.authorization.k8s.io/traefik-ingress-controller created
````

##  Deploy the Traefik controller

We use this Traeffik [version](https://github.com/containous/traefik/releases/tag/v1.7.13)

Download example
```
curl -L  https://github.com/containous/traefik/archive/v1.7.13.tar.gz --output traefikv1.7.13.tar.gz
vagrant@k8sMaster:~$ file traefikv1.7.13.tar.gz*
traefikv1.7.13.tar.gz: gzip compressed data, from Unix
vagrant@k8sMaster:~/traefik-1.7.13$ vi ./examples/k8s/traefik-ds.yaml
```
Modiy example to :
- Add host network, remove capabilities
- Change label app 
- Add selector  https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/
- And declare version 1.7.13 dans le daemonset
```
containers:
- image: traefik:1.7.13
```
Otherwise error:
````
vagrant@k8sMaster:~/traefik-1.7.13$ k logs -f traefik-ingress-controller-z5vmm --namespace kube-system
2020/01/31 10:15:21 command traefik error: failed to decode configuration from flags: field not found, node: kubernetes
https://github.com/containous/traefik/issues/5422
````
File should be like this:

````
vagrant@k8sMaster:~$ cat traefik-1.7.13/examples/k8s/traefik-ds.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-lb
spec:
  selector:
    matchLabels:
      name: traefik-ingress-lb
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      serviceAccountName: traefik-ingress-controller
      terminationGracePeriodSeconds: 60
      hostNetwork: true
      containers:
      - image: traefik:1.7.13
        name: traefik-ingress-lb
        ports:
        - name: http
          containerPort: 80
          hostPort: 80
        - name: admin
          containerPort: 8080
          hostPort: 8080
        args:
        - --api
        - --kubernetes
        - --logLevel=INFO
---
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
    - protocol: TCP
      port: 80
      name: web
    - protocol: TCP
      port: 8080
      name: admin
vagrant@k8sMaster:~$
````

Deploy the ingress controller

Eventually do `k delete -f` before.

````
vagrant@k8sMaster:~$ k get pods --namespace kube-system | grep traef
vagrant@k8sMaster:~$ k apply -f traefik-1.7.13/examples/k8s/traefik-ds.yaml
serviceaccount/traefik-ingress-controller created
daemonset.apps/traefik-ingress-controller created
service/traefik-ingress-service created
vagrant@k8sMaster:~$ k get pods --namespace kube-system | grep traef
traefik-ingress-controller-pwv2d           1/1     Running   0          6s
````

##  Create the ingress rules

````
vagrant@k8sMaster:~$ cat ingress.rule.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-test
  namespace: default
spec:
  rules:
  - host: www.example.com
    http:
      paths:
      - backend:
          serviceName: deploy1
          servicePort: 80
        path: /
  - host: www.yolo.org
    http:
      paths:
      - backend:
          serviceName: deploy2
          servicePort: 80
        path: /
vagrant@k8sMaster:~$
````

Deploy the rule
Eventually do `k delete ingress ingress-test` beofre.

````
vagrant@k8sMaster:~$ k apply -f ingress.rule.yaml
ingress.extensions/ingress-test created
````

## And target the ingress

````
vagrant@k8sMaster:~$ curl -H "Host: www.example.com" http://127.0.0.1/
deploy1-5d98f66655-gqgdq
vagrant@k8sMaster:~$ curl -H "Host: www.example.com" http://127.0.0.1/
deploy1-5d98f66655-pgrdl
vagrant@k8sMaster:~$ curl -H "Host: www.yolo.org" http://127.0.0.1/
deploy2-5ff54b6b7b-npnsh
vagrant@k8sMaster:~$ curl -H "Host: www.yolo.org" http://127.0.0.1/
deploy2-5ff54b6b7b-z7fgp
````

example `Host` header routing to deploy1 and yolo to deploy 2.

Note that NodePort still working

````
vagrant@k8sMaster:~$ curl 127.0.0.1:32000
deploy2-5ff54b6b7b-94kbj
````

And that each time we use 127.0.0.1, we can use VM IP address

````
vagrant@k8sMaster:~$ curl 10.0.2.15:32000
deploy2-5ff54b6b7b-npnsh
vagrant@k8sMaster:~$ curl -H "Host: www.yolo.org" http://10.0.2.15
deploy2-5ff54b6b7b-94kbj
````


## As for NodePort we can use forwarded port outside  VM 

This is equivalent to target ip address of the node from the outside
 
It is working because we defined port forwarding rule: `k8sMaster.vm.network "forwarded_port", guest: 80, host: 9980, auto_correct: true`.

results:

````
scoulomb@ XXXXX MINGW64 ~
$ curl --silent -H "Host: www.example.com" http://127.0.0.1:9980
deploy1-5d98f66655-gqgdq

scoulomb@ XXXXX MINGW64 ~
$ curl --silent -H "Host: www.yolo.org" http://127.0.0.1:9980
deploy2-5ff54b6b7b-z7fgp
````

## If service is undefined

````
scoulomb@ XXXXX MINGW64 ~
$ curl --silent -H "Host: www.yolo-donotexist.org" http://127.0.0.1:9980
404 page not found
````

## See Traefik GUI

Available on port 8880 if done:
`k8sMaster.vm.network "forwarded_port", guest: 8080, host: 8880, auto_correct: true`

![traefik 1](images/Screenshot_2020-02-02-Traefik.png)
![traefik 2](images/Screenshot_2020-02-02-Traefik2.png)

We can `backend` ips are pods ip

````
vagrant@k8sMaster:~$ k get pods -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP               NODE        NOMINATED NODE   READINESS GATES
deploy1-5d98f66655-d8np4   1/1     Running   0          77m   192.168.16.191   k8smaster   <none>
        <none>
deploy1-5d98f66655-gqgdq   1/1     Running   0          77m   192.168.16.190   k8smaster   <none>
        <none>
deploy1-5d98f66655-pgrdl   1/1     Running   0          77m   192.168.16.132   k8smaster   <none>
        <none>
deploy2-5ff54b6b7b-94kbj   1/1     Running   0          77m   192.168.16.134   k8smaster   <none>
        <none>
deploy2-5ff54b6b7b-npnsh   1/1     Running   0          77m   192.168.16.133   k8smaster   <none>
        <none>
deploy2-5ff54b6b7b-z7fgp   1/1     Running   0          77m   192.168.16.189   k8smaster   <none>
        <none>
````

## Implementation details

From the doc Traefik controller is watching endpoints and ingress resources
As seen here: https://docs.traefik.io/v1.7/user-guide/kubernetes/
> Traefik will now look for cheddar service endpoints (ports on healthy pods) in both the cheese and the default namespace. Deploying cheddar into the cheese namespace and afterwards shutting down cheddar in the default namespace is enough to migrate the traffic.

It most likely also needs RBAC on service to find service (same as endpoint) label, because the ingress resource takes the service name.
Note endpoint exists because of service (endpoints controller) 

It can also use the kube-proxy: as explained in [traefik doc](https://kubernetes.io/docs/concepts/configuration/overview/#services)
> DaemonSets can be run with the NET_BIND_SERVICE capability, which will allow it to bind to port 80/443/etc on each host. This will allow bypassing the kube-proxy, and reduce traffic hops. Note that this is against the Kubernetes [Best Practices Guidelines](https://kubernetes.io/docs/concepts/configuration/overview/#services), and raises the potential for scheduling/scaling issues. Despite potential issues, this remains the choice for most ingress controllers.

cf. [StackOverflow response](https://stackoverflow.com/questions/60031377/load-balancing-in-front-of-traefik-edge-router) with the update.

Nginx ingress controller is also watching endpoint. From this [article](https://itnext.io/managing-ingress-controllers-on-kubernetes-part-2-36a64439e70a
> the k8s-ingress-nginx controller uses the service endpoints instead of its virtual IP address.

See complementary articles:
- https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
- https://www.haproxy.com/fr/blog/dissecting-the-haproxy-kubernetes-ingress-controller/

## OpenShift route (HA proxy)

OpenShift Route is equivalent to Ingress
Cf. this [OpenShift blogpost](https://blog.openshift.com/kubernetes-ingress-vs-openshift-route/)
From [OpenShift HA proxy doc](https://docs.okd.io/latest/architecture/networking/assembly_available_router_plugins.html#architecture-haproxy-router):
> The template router has two components:
> -  A wrapper that watches endpoints and routes and causes a HAProxy reload based on changes
> - A controller that builds the HAProxy configuration file based on routes and endpoints

Thus it seems OpenShift route bypass also `kube-proxy`


## Single point of failure

To avoid SPOF, we load balance on all nodes where Traefik is running ([daemonset](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset)) which then redispatch to a pod potentially in different node?
(or DNS load balancing)

See this question: 
https://stackoverflow.com/questions/60031377/load-balancing-in-front-of-traefik-edge-router

> Looking at OpenShift HA proxy or Traefik project: https://docs.traefik.io/. I can see Traefik ingress controller is deployed as a DaemonSet. It enables to route traffic to correct services/endpoints using virtual host.
> Assuming I have a Kubernetes cluster with several nodes. How can I avoid to have a single point of failure?
> Should I have a load balancer (or DNS load balancing), in front of my nodes?
> If yes, does it mean that:
> 1. Load balancer will send traffic to one node of k8s cluster
> 2. Traefik will send the request to one of the endpoint/pods. Where this pod could be located in a different k8s node?
>
> Does it mean there would be a level of indirection?
> I am also wondering if the F5 cluster mode feature could avoid such indirection?
> EDIT (post 2nd response): when used with [F5 Ingress resource](https://clouddocs.f5.com/containers/v2/kubernetes/kctlr-k8s-ingress-ctlr.html#set-a-default-shared-ip-address)

Answers I got is:

> You should have a load balancer (BIG IP from F5 or a software load balancer) for traefik pods. When client request comes in it will sent to one of the traefik pods by the load balancer. Once request is in the traefik pod traefik will send the request to cluster IP of the kubernetes workload pods based on ingress rules.You can configure L7 load balancing in traefik for your workload pods.Once the request is in clusterIP from there Kube proxy will perform L4 load balancing to your workload pods IPs.

After correction on Kube-proxy made as a comment, and explained [here](#Implementation details), 2nd response:

> You can have a load balancer (BIG IP from F5 or a software load balancer) for traefik pods. When client request comes in it will sent to one of the traefik pods by the load balancer. Once request is in the traefik pod traefik will send the request to IPs of the kubernetes workload pods based on ingress rules by getting the IPs of those pods from kubernetes endpoint API.You can configure L7 load balancing in traefik for your workload pods.
> Using a software reverse proxy such as nginx and exposing it via a load balancer introduces an extra network hop from the load balancer to the nginx ingress pod.
> Looking at the F5 docs BIG IP controller can also be used as ingress controller and I think using it that way you can avoid the extra hop.

So answer is yes.

As such we have following steps:

1. DNS targeting a VIP (used later by vhost) 
2. F5 load balancer exposing a VIP with pool members being (Nodes -> cluster nodes, Port -> NodePort). Note [1 + 2] can be replaced by a DNS round robin
3. The load balancer will actually target a [NodePort service type](./service_deep_dive.md#NodePort) pointing to Ingress controller pod (L3 routing).
Alternative (2+3). OR we can also bind ingress controller on each node directly to port 88/443 (privileged port) to [bypass `kube-proxy`](#Implementation-details)
4. Ingress controller redirect to correct service / endpoint / pod using vhost header (L7 routing). 
5. Ingress controller forwards to correct service which directs to pod (this is usually done via [ip table direcly](#service-internal) ).

(Note endpoints created by endpoint controller based on pod and service label, iptable updated by kube-proxy based on endpoints and service )

So we have until until 3 levels of indirection, but usually only 2 because `kube-proxy` is bypassed. 

A [load balancer service type](./service_deep_dive.md#LoadBalancer) could be used instead

I assume OpenShift route is the Alternative (2+3)

Next: [F5 integration](./k8s_f5_integration.md)