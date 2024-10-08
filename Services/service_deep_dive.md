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

Rather than targeting pod directly we can use service
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

This is possible because from [k8s doc](https://kubernetes.io/docs/concepts/services-networking/service/)
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

Let's deep dive on how `ClusterIP` service type is working.

`kube-proxy` watches endpoints and services to updates iptable and thus redirect to correct pod.

It has several [modes](https://kubernetes.io/docs/reference/networking/virtual-ips/#proxy-modes)
- `userspace` proxy (it was a real proxy) [deprecated now]: https://kubernetes.io/blog/2022/11/18/upcoming-changes-in-kubernetes-1-26/#removal-of-kube-proxy-userspace-modes)
- `iptable` : update ip table based on service cluster ip (virtual server) and endpoints (pool members)
- `ipvs` (netlinks)
- `nftables` [new]
- and `kernelspace` [new]

Note all our examples are given with `iptables`
<-- userspace mode: expect proxy to listen on svc (cluster IP, Port), (NodeIP, Port) : cf [](#notes-on-ports). Forward traffic, mechanism described for iptable in this doc section. For NodePort additional NAT chain and TCP listen described [](#nodeport) -->

kube-proxy is not used (cf. https://kubernetes.io/docs/reference/networking/virtual-ips) for [external name](#external-name)

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

See details of KubeProxy in this blog post: https://kodekloud.com/blog/kube-proxy/ (local copy at [resources](./resources/Kube-Proxy:%20What%20Is%20It%20and%20How%20It%20Works.pdf))

> Kube-proxy helps with Service to pod mapping by maintaining a network routing table that maps Service IP addresses to the IP addresses of the pods
> that belong to the Service.
> When a request is made to a Service, kube-proxy uses this mapping to forward the request to a Pod belonging to the Service.

In summary here is how `kube-proxy` works

- Service is `SVC01` created with a `cluster IP`. Service has a label selector `app: X` 
- New pods are created with a label `app: X`. Those pods have a pod IP. Assume `pod_1 ip_1`. `pod_2 ip_2` 
- API server triggers creation of an endpoint with pod's label `app: X`. Assume `EP01`, `EP02` respectively to `pod_1 ip_1`. `pod_2 ip_2`
- API server will check POD to be associated to service `svc01`. It will look for endpoints (pods) matching the service label selector `app: X`.
Here `EP01`, `EP02`
- API server will map the `SVC01` / `cluster IP` to `EP01`, `EP02`
- We want this mapping to be implemented on the network so that traffic coming to the IP of `SVC01` can be forwarded to `EP01` or `EP02`.
- To achieve that, the API server advertises the new mapping to the Kube-proxy on **each node**, which then applies it as an internal rule.
- This rules is applied as a set of **DNAT rules** 
- So that a request to `cluster IP` coming from another POD inside to same cluster is sent to pod `EP01` xor `EP02` <=> `pod_1 ip_1` xor `pod_2 ip_2`
- Targeted POD can be in a different node of the source pod node

Note the port is set using `port` (target port of svc) and `targetPort` (port targeted after the svc) in service manifest: https://kubernetes.io/docs/concepts/services-networking/service/
> A Service can map any incoming port to a targetPort. By default and for convenience, the targetPort is set to the same value as the port field.

Or equivalent via `expose`: https://jamesdefabia.github.io/docs/user-guide/kubectl/kubectl_expose/

See [use different port below](#use-a-different-port-)

 **DNAT rules details** 

````shell
iptables -t nat -L PREROUTING -> KUBE-SERVICES
iptables -t nat -L KUBE-SERVICES -> Chain with target IP of svc (cluster IP) -> <CHAIN_NAME> = <KUBE-SVC-XXXX>
iptables -t nat -L  <KUBE-SVC-XXXX> -> Chain with EPO1, EPO2 -> <CHAIM_NAME> = <KUBE-SEP-XXX>. SEP=Service EndPoint
iptables -t nat -L   <KUBE-SEP-XXX> -> DNAT rule to POD IP and service target Port (pod IP is cut in KodeCloud doc but well visible here: https://ronaknathani.com/blog/2020/07/kubernetes-nodeport-and-iptables-rules/.)
````

See [NodePort](#NodePort) chain extension.

Note on ClusterIP allocation: https://kubernetes.io/docs/concepts/services-networking/cluster-ip-allocation/#how-service-clusterips-are-allocated


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

See comment on port in [service internal](#service-internal)

## Other type of service

Service we have seen above is `ClusterIP`.

### NodePort

`NodePort` is a simple connection from a high-port routed to a `ClusterIP`. `NodePort` service type is an extension of `ClusterIP` service type.

See [cluster IP details](#service-internal)

The NodePort is accessible via calls to `<NodeIP>:<NodePort>`.

`NodePort` is following the same mechanism as `ClusterIP` service type describe in [service internals](#service-internal) using kube-proxy.
Port is added to DNAT rules with a new chain.

````shell
iptables -t nat -L PREROUTING -> KUBE-SERVICES
iptables -t nat -L KUBE-SERVICES -n -> Chain KUBE-NODEPORTS and Chain with target IP of svc (cluster IP) -> <CHAIN_NAME> = <KUBE-SVC-XXXX>
iptables -t nat -L KUBE-NODEPORTS -n  -> And we find the svc again <KUBE-SVC-XXXX>. which matches the one with the cluster IP (clusterIP `10.0.237.3` and `KUBE-SVC-GHSLGKVXVBRM4GZX` in the example)
iptables -t nat -L <KUBE-SVC-XXXX> -> Chain with EPO1, EPO2 -> <CHAIM_NAME> = <KUBE-SEP-XXX>. SEP=Service EndPoint
iptables -t nat -L  <KUBE-SEP-XXX> -> DNAT rule to POD IP and service target Port
````

Here we have `<KUBE-SVC-XXXX>` which matches `spec.ports.clusterIP` in the routing chain, but not use since we access this chain from `KUBE-NODEPORTS`.

Examples: https://ronaknathani.com/blog/2020/07/kubernetes-nodeport-and-iptables-rules/. <!-- check IP match stop here OK YES -->

Local copy in [resources](./resources/Kubernetes%20NodePort%20and%20iptables%20rules%20%7C%20Ronak%20Nathani.pdf).

Thus `NodePort` effect is to add additional Chain.
Other chain are intact compared to a standard `ClusterIP` svc.
Also note only the last chain has a chain of type `DNAT`, other types are `Chain`,

Kube-proxy is also listening on NodePort

````shell
$ sudo lsof -i:30450
COMMAND     PID USER   FD   TYPE   DEVICE SIZE/OFF NODE NAME
hyperkube 11558 root    9u  IPv6 95841832      0t0  TCP *:30450 (LISTEN)

$ ps -aef | grep -v grep | grep 11558
root      11558  11539  0 Jul02 ?        00:06:37 /hyperkube kube-proxy --kubeconfig=/var/lib/kubelet/kubeconfig --cluster-cidr=10.244.0.0/16 --feature-gates=ExperimentalCriticalPodAnnotation=true --v=3
````

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

`NodePort ` can be found in manifest: https://kubernetes.io/docs/concepts/services-networking/service/#nodeport-custom-port

### LoadBalancer

Doc: https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/

Creating a LoadBalancer service generates a NodePort. `LoadBalancer` service type is an extension of [`NodePort`](#nodeport) service type. 
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

It will load balancer on cluster nodes.
There will be two pool members associated with the load balancer: 
These are the IP addresses of the nodes in the Kubernetes cluster.

We could setup load balancer manually.

### Notes on ports

We have seen following port
- [clusterIP](#service-internal)
  - `ports.port`
  - `ports.targetPort`
- [NodePort](#Nodeport)
  - `ports.nodePort`

I did not see a field for load balancer port, most implem seem to use same port as `ports.port` as virtual lb port: https://mcorbin.fr/posts/2021-12-13-kubernetes-external-policy/

Also `LoadBalancer` Service type can create a `healthCheckNodePort`

From doc. See https://matthewpalmer.net/kubernetes-app-developer/articles/kubernetes-ports-targetport-nodeport-service.html

> nodePort
> This setting makes the service visible outside the Kubernetes cluster by the node’s IP address and the port number declared in this property. The service also has to be of type NodePort (if this field isn’t specified, Kubernetes will allocate a node port automatically).

> port
> Expose the service on the specified port internally within the cluster. That is, the service becomes visible on this port, and will send requests made to this port to the pods selected by the service.

> targetPort
> This is the port on the pod that the request gets sent to. Your application needs to be listening for network requests on this port for the service to work.


### Note on load balancer svc

<!-- discussion dl jum2020 -->

````shell script
➤ k create service loadbalancer my-lbs --tcp=5678:8080                                                                                                                 
service/my-lbs created
[11:27] ~
➤ k get svc my-lbs                                                                                                                                                         
NAME     TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
my-lbs   LoadBalancer   10.110.153.149   <pending>     5678:31434/TCP   5s
[11:27] ~
➤ k get svc my-lbs -o yaml                                                                                                                                               
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: "2020-05-06T11:27:52Z"
  labels:
    app: my-lbs
  name: my-lbs
  namespace: default
  resourceVersion: "1367"
  selfLink: /api/v1/namespaces/default/services/my-lbs
  uid: dff78db2-fb01-4528-b9b3-ed93b6c20fc8
spec:
  clusterIP: 10.110.153.149
  externalTrafficPolicy: Cluster
  ports:
  - name: 5678-8080
    nodePort: 31434
    port: 5678
    protocol: TCP
    targetPort: 8080
  selector:
    app: my-lbs
  sessionAffinity: None
  type: LoadBalancer
status:
  loadBalancer: {}
````

- NodePort service type => service with a clusterIp AND NodePort 
- LoadBalancer service type  => service with  a (ClusterIP AND NodePort) AND "external load balancer routes"  <=> service with  a NodePort AND "external load balancer routes" 

See doc: https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types

<!-- dl nodeport not accessible but it is and it used by the load balancer
confirmed by ales nosek 
-->

In azure we can set the load balancer IP: https://docs.microsoft.com/en-us/azure/aks/static-ip



### Note on External traffic policy

#### What it is 

We can also force NodePort to route to local using field [service.spec.externalTrafficPolic](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip).
This avoids extra hop on another node and SNAT.


````shell script
➤ sudo kubectl explain service.spec.externalTrafficPolicy
KIND:     Service
VERSION:  v1

FIELD:    externalTrafficPolicy <string>

DESCRIPTION:
     externalTrafficPolicy denotes if this Service desires to route external
     traffic to node-local or cluster-wide endpoints. "Local" preserves the
     client source IP and avoids a second hop for LoadBalancer and Nodeport type
     services, but risks potentially imbalanced traffic spreading. "Cluster"
     obscures the client source IP and may cause a second hop to another node,
     but should have good overall load-spreading.
````


But from https://www.asykim.com/blog/deep-dive-into-kubernetes-external-traffic-policies
> With this architecture, it’s important that any ingress traffic lands on nodes that are running the corresponding pods for that service, otherwise, the traffic would be dropped

A solution could be to use load balancer health check on the NodePort. This is what [GKE is doing](https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-loadbalancer).

From doc: https://kubernetes.io/docs/tutorials/services/source-ip/: external traffic policy has an impact on source ip.
See details here: https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-nodeport and impact on [NAT](#externaltrafficpolicy).

 
I recommend to read: 
- https://www.asykim.com/blog/deep-dive-into-kubernetes-external-traffic-policies
- https://web.archive.org/web/20210205193446/https://www.asykim.com/blog/deep-dive-into-kubernetes-external-traffic-policies

Note this is link to that article where we had seen cluster ip
https://github.com/scoulomb/myDNS/blob/2b846f42f7443e84fc667ae3f3f66188f1c69259/2-advanced-bind/1-bind-in-docker-and-kubernetes/2-understand-source-ip-in-k8s.md
and it references this doc
https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-clusterip
When they talk on source ip preservation on node port and lb service depending on external traffic policy.
Note as mention externalTrafficPolicy does not apply to clusterIP (internal OK).



#### Mirror server

To observe this they use a mirror server.
We had made one here: https://github.com/scoulomb/http-over-socket

<!--
here also MAES orchestrator has one Mirror.java
and referenced in https://github.com/scoulomb/private_script/blob/main/sei-auto/certificate/certificate.md is OK, no impact
already seen this https://kubernetes.io/docs/tutorials/services/source-ip osef
-->

See also: https://matthewpalmer.net/kubernetes-app-developer/articles/kubernetes-networking-guide-beginners.html
<!-- mirrored https://github.com/scoulomb/private_script/blob/main/sei-auto/certificate/certificate-doc/k8s-networking-guide/network-guide.md -->

#### When not done 

In K8s doc when not using `externalTrafficPolicy` with `NodePort` and `LoadBalancer` service type,
they mention we are doing:
- `SNAT` (replaces the source IP address (SNAT) in the packet with its own IP address)
- + `DNAT` (replaces the destination IP on the packet with the pod IP)
https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-nodeport

What does it mean?

From: https://superuser.com/questions/1410865/what-is-the-difference-between-nat-and-snat-dnat/1410870

> "NAT" is a collective term for various translations - usually it's actually NAPT (involving the transport-layer port numbers as well).

> Source NAT translates the source IP address,
> usually when connecting from a private IP address to a public one ("LAN to Internet").

What happens when we use Internet

> Destination NAT translates the destination IP address,
> usually when connecting from a public IP to a private IP (aka port-forwarding, reverse NAT, expose host, "public server in LAN").

What happens when we configure NAT on the box

See here SNAT@home/DNAT@home: https://github.com/scoulomb/docker-under-the-hood/tree/main/NAT-deep-dive-appendix#cisco-nat-classification

Reverse NAT is similar to this:
https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-f.md#analysis
So in this case [if using ingress with NodePort in step 3](#when-using-ingress) we would apply NAT at box and inside the cluster.

Here we details internal behavior: https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-nodeport

The SNAT is NO SRC
Similar to F5 to Node described here: https://github.com/scoulomb/docker-under-the-hood/tree/main/NAT-deep-dive-appendix#section-about-securenats
> This is not same SNAT as @home.. It is SNAT between F5 and application (gateway).

And DNAT same as @home.

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
So usable only inside a pod using DNS discovery


### Service without a selector

Controller when there is label creates endpoint
But can define it manually in particular to target outside resource

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

Note service `my-service` has for type `ClusterIP`.

### headless service

Note there is also headless service: 
https://kubernetes.io/docs/concepts/services-networking/service/#headless-services

Here I give an example with selector.

````shell script
# create a deployment with 3 replicas
kubectl delete deployment --all
kubectl delete svc --all 

kubectl create deployment deploy1 --image=nginx
kubectl scale deployment deploy1 --replicas=3
kubectl get pods -o wide

# non headless svc
echo 'apiVersion: v1
kind: Service
metadata:
  name: my-non-headless-service
spec:
  selector:
    app: deploy1
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
' > my-non-headless-service.yaml 
kubectl delete -f my-non-headless-service.yaml 
kubectl apply -f my-non-headless-service.yaml

# headless svc
echo 'apiVersion: v1
kind: Service
metadata:
  name: my-headless-service
spec:
  clusterIP: None # clusterIP set to None for headless
  selector:
    app: deploy1
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
' > headless-svc.yaml
kubectl delete -f headless-svc.yaml # field cluster ip is immutable
kubectl apply -f headless-svc.yaml

# doctor for experiment
# https://github.com/scoulomb/docker-doctor
kubectl delete deployment doctor 
kubectl create deployment doctor --image=scoulomb/docker-doctor:dev
# kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- bash

````

Let's do some observations

````shell script
kubectl get po -o wide | grep deploy1-
kubectl get svc | grep headless
kubectl get ep | grep headless


kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- env | grep -i headless

kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- nslookup my-non-headless-service
kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- nslookup my-headless-service

kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- curl my-non-headless-service | head -n 5
kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- curl my-headless-service | head -n 5

````

Output is 

````shell script
root@sylvain-hp:/home/sylvain# kubectl get po -o wide | grep deploy1-
deploy1-5b979f7745-6lc7f   1/1     Running   0          63s   172.17.0.4   sylvain-hp   <none>           <none>
deploy1-5b979f7745-n9dt7   1/1     Running   0          63s   172.17.0.5   sylvain-hp   <none>           <none>
deploy1-5b979f7745-wcscr   1/1     Running   0          63s   172.17.0.6   sylvain-hp   <none>           <none>
root@sylvain-hp:/home/sylvain# kubectl get svc | grep headless
my-headless-service       ClusterIP   None            <none>        80/TCP    46s
my-non-headless-service   ClusterIP   10.97.238.145   <none>        80/TCP    47s
root@sylvain-hp:/home/sylvain# kubectl get ep | grep headless
my-headless-service       172.17.0.4:80,172.17.0.5:80,172.17.0.6:80   49s
my-non-headless-service   172.17.0.4:80,172.17.0.5:80,172.17.0.6:80   50s
````

````shell script
root@sylvain-hp:/home/sylvain# kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- env | grep -i headless
MY_NON_HEADLESS_SERVICE_PORT_80_TCP_PORT=80
MY_NON_HEADLESS_SERVICE_PORT_80_TCP_ADDR=10.97.238.145
MY_NON_HEADLESS_SERVICE_PORT=tcp://10.97.238.145:80
MY_NON_HEADLESS_SERVICE_PORT_80_TCP_PROTO=tcp
MY_NON_HEADLESS_SERVICE_SERVICE_HOST=10.97.238.145
MY_NON_HEADLESS_SERVICE_SERVICE_PORT_HTTP=80
MY_NON_HEADLESS_SERVICE_PORT_80_TCP=tcp://10.97.238.145:80
MY_NON_HEADLESS_SERVICE_SERVICE_PORT=80
````

we can see headless does not have env var discovery

````shell script
root@sylvain-hp:/home/sylvain# kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- nslookup my-non-headless-service
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   my-non-headless-service.default.svc.cluster.local
Address: 10.97.238.145

root@sylvain-hp:/home/sylvain# kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- nslookup my-headless-service
Server:         10.96.0.10
Address:        10.96.0.10#53

Name:   my-headless-service.default.svc.cluster.local
Address: 172.17.0.6
Name:   my-headless-service.default.svc.cluster.local
Address: 172.17.0.4
Name:   my-headless-service.default.svc.cluster.local
Address: 172.17.0.5
````

Here we can DNS resolution pointing to cluster IP vs Pod IP (round robin as seen [here](https://github.com/scoulomb/myDNS/blob/b310d9cdf3fc1a6476d0dd6e16d0a5ee53c2df78/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-k.md#curisoity)).
 
We could have a weird entry where we have a A pointing to the node IP, if we have a hostnetwork pod (as the Pod IP will be the IP of the node)
See [here](#use-hostport-and-hostnetwork-together), where deployment match same label.
Also if no pod is matching a headless service label, no record is created.

````shell script
root@sylvain-hp:/home/sylvain# kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- curl my-non-headless-service | head -n 5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
root@sylvain-hp:/home/sylvain# kubectl exec -it $(kubectl get po | grep doctor | awk '{print $1}') -- curl my-headless-service | head -n 5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
````

Here we can sere curl is working.

<!-- traceroute and ping seems to work well for non headless unlike headless. STOP HERE -->
<!-- externalName can be seen as without selector OK -->


### To sum-up
<!-- here above all ccl - CCL -->

We have 4 service types

#### [`ClusterIP`](#service-internal)

````
Internal Traffic -> Worker Node [svc.spec.clusterIP, svc.spec.ports.port]-> DNAT rules generated from Kube-Proxy using (svc.spec.clusterIP and svc.ports.port) to (podId, spec.ports.TargetPort) ->[podIp, spec.ports.TargetPort] distributing to set of PODs  
````
POD can be in same worker node or not. Same apply for other service type after DNAT rules, intra-cluster node to node is no shown in this representation

#### [`NodePort`](#NodePort) = `ClusterIP` + high routed port


````
External Traffic -> Worker Node [1 WorkerNode IP, spec.ports.NodePort] -> DNAT rules generated from Kube-Proxy using (svc.ports.NodePort) to (podId, spec.ports.TargetPort) ->[podIp, spec.ports.TargetPort] distributing to set of PODs  
````

As explained in [`NodePort`](#NodePort), we have  `svc.spec.clusterIP` in the chain but linking is done via `svc.ports.NodePort`

We can load balancer manually across worker nodes



#### [`LoadBalancer`](#LoadBalancer) = `NodePort` + LB


````
External Traffic -> Provisioned Azure Load Balancer  [External LB IP, spec.ports.port] ->  Worker Node [1 WorkerNode IP, spec.ports.NodePort] -> DNAT rules generated from Kube-Proxy using (svc.ports.NodePort) to (podId, spec.ports.TargetPort) -> [podIp, spec.ports.TargetPort] distributing to set of PODs  
````

As explained in [`NodePort`](#NodePort), we have  `svc.spec.clusterIP` in the chain but linking is done via `svc.ports.NodePort`

We give example of AZ LB but each cloud provider has its implem.

Alternative is to use a NodePort and do own load balancing manually, it is equivalent to load balancer type, except that LB will not be automatically provisioned.

External LB IP can be provided: https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard#restrict-inbound-traffic-to-specific-ip-ranges and `service.beta.kubernetes.io/azure-load-balancer-ipv4`.

Provisioned means platform Provisioned

See summary of port in load balancer section [here](#loadbalancer)

#### External name

Kube-proxy is not used (cf. https://kubernetes.io/docs/reference/networking/virtual-ips) for [external name](#external-name)


No proxying, full GTM

````
Internal Traffic - - -> DNS resolution `<service-name>.svc` to CNAME
                 - - -> Resolve CNAME to IP
                 -> Targets IP
````
        


NB: [Headless services](#headless-service) and [service without selector](#service-without-a-selector) can be combined together, and also with the service type.

Each service has related internal DNS record in `<service-name>.svc` to `clusterIP`. [Refer to](#svc-discovery-by-environment-variable-or-dns-within-a-pod)

Looking at: https://learn.microsoft.com/en-us/azure/aks/concepts-network-services, we understand well and see simplification made! (forked here: https://github.com/scoulomb/azure-aks-docs/blob/main/articles/aks/concepts-network-services.md)

<!-- summary and here fully ccl OK OKCF -->

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

Below we use Node IP

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


### Traefik to POD

This is the southbound part

**The route/ingress does not actually target the service IP and then the pod via DNAT rule created via `kube-proxy`.** as seen in [Cluster IP section](#service-internal).

From the doc Traefik controller is watching endpoints and ingress resources
As seen here: https://docs.traefik.io/v1.7/user-guide/kubernetes/
> Traefik will now look for cheddar service endpoints (ports on healthy pods) in both the cheese and the default namespace. Deploying cheddar into the cheese namespace and afterwards shutting down cheddar in the default namespace is enough to migrate the traffic.

It most likely also needs RBAC on service to find service (same as endpoint) label, because the ingress resource takes the service name.
Note endpoint exists because of service (endpoints controller) 

Similarly Nginx ingress controller is also watching endpoint. From this [article](https://itnext.io/managing-ingress-controllers-on-kubernetes-part-2-36a64439e70a
> the k8s-ingress-nginx controller uses the service endpoints instead of its virtual IP address.

Thus `kube-proxy` is not used between ingress and pods.

**It explain why a single TCP connection is opened between ingress and PODs.**

Evidence, code snippets and rational is given in this github issue: https://github.com/traefik/traefik/issues/5322

<!-- so not a question of network layer -->

So it works as follows

````text
Southbound: -> Ingress pod is applying rules defined in Ingress resource. It select a k8s service. We call it selectedSvc in this doc (**) -> [podIp, selectedSvc.ports.TargetPort] distributing to set of PODs IP (matching svc label)
````

(**) How did Ingress operator identify podIP without `kube-poxy`. It is actually performing a similar work to [`kube-proxy`](#service-internal)

- Service is `SVC01` created with a `cluster IP`. Service has a label selector `app: X`
- New pods are created with a label `app: X`. Those pods have a pod IP. Assume `pod_1 ip_1` . `pod_2 ip_2`
- API server triggers creation of an endpoint with pod's label  `app: X`. Assume `EP01`, `EP02` respectively to `pod_1 ip_1`. `pod_2 ip_2`
- Ingress operator will checks it rules definition
- Assume a rule has to be associated to `svc01`. Operator will look for endpoints (pods) matching the service label selector `app: X`. Here `EP01`, `EP02`
- Operator will map the rule linked to `SVC01` to `EP01`, `EP02`.
- It will use the target port in the svc definition


### Client to Ingress itself is a using standard k8s service but it can also bind port on node 

This is the northbound part.

Ingress itself can also use the `kube-proxy` or not: as explained in [traefik doc](https://doc.traefik.io/traefik/v1.7/user-guide/kubernetes/) or in source [here](https://github.com/scoulomb/traefik/blob/v1.7/docs/user-guide/kubernetes.md).
> DaemonSets can be run with the NET_BIND_SERVICE capability, which will allow it to bind to port 80/443/etc on each host. This will allow bypassing the kube-proxy, and reduce traffic hops. Note that this is against the Kubernetes [Best Practices Guidelines](https://kubernetes.io/docs/concepts/configuration/overview/#services), and raises the potential for scheduling/scaling issues. Despite potential issues, this remains the choice for most ingress controllers.

With the 2 deployment modes described in the doc:

#### Option A: use `NodePort` 

(or `LoadBalancer` service type which is a super set). We can also use `NodePort` with a custom load balancer, not operated via k8s, like an F5 device.

> The Service will expose two NodePorts which allow access to the ingress and the web interface.  

=> `kube-proxy` is used between client and ingress PODs, as depicted in [summary](#to-sum-up) (northbound). 
=> `kube-proxy` is not used between ingress and pods (southbound).

**We use a `Deployment` + a service [`NodePort`](#nodeport) with 2 ports for the ingress: https://doc.traefik.io/traefik/v1.7/user-guide/kubernetes/#deploy-traefik-using-a-deployment-or-daemonset**

It works as follows:

````
Northbound:
External Traffic ->  Provisioned (Azure) Load Balancer  [External LB IP, spec.ports.port] (svc type is LB) XOR LB not operated by k8s XOR NO LB
->  Worker Node [1 WorkerNode IP, spec.ports.NodePort] -> DNAT rules generated from Kube-Proxy using (svc.ports.NodePort) to (podId, spec.ports.TargetPort)
-> [podIp, spec.ports.TargetPort] distributing to set of Ingress PODs 
````

Note: Node on which we are distributed can contain ingress pod or not, if not: request sent to other node, and same for pod after selected svc. 

Note: if we deploy Ingress as DaemonSet we can use local [external traffic policy](#note-on-external-traffic-policy) for Ingress NodePort (LoadBalancer) service
since we always have a Ingress pod running on each node!

**When using option A, it is well visible that Ingress is a particular case of [`NodePort`](#nodeport) or [`Loadbalancer`](#loadbalancer) service type**

Where ClusterIP < NodePort < LoadBalancer.

#### Option B: bind a port in Node


**We use `DaemonSet` + `NET_BIND_SERVICE` capability + container `hostPort`.**

- > This will create a Daemonset that uses privileged ports 80/8080 on the host. This may not work on all providers, but illustrates the static (non-NodePort) hostPort binding.
  > The traefik-ingress-service can still be used inside the cluster to access the DaemonSet pods. 

=> `kube-proxy` is NOT used at all for both northbound and southbound part.


We need a `DaemonSet` to have the ingress on each node (as we do not use `Service` here even if created in doc example: https://doc.traefik.io/traefik/v1.7/user-guide/kubernetes/#deploy-traefik-using-a-deployment-or-daemonset but quoting it
> The traefik-ingress-service can still be used inside the cluster to access the DaemonSet pods

We used second mode in example above (where capabilities are not explicit as allowed by default).

cf. [StackOverflow response](https://stackoverflow.com/questions/60031377/load-balancing-in-front-of-traefik-edge-router) with the update.


See complementary articles:
- https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/
- https://www.haproxy.com/fr/blog/dissecting-the-haproxy-kubernetes-ingress-controller/

See [host port](#host-port)

It works as follows 


````
Northbound:
External Traffic ->  Provisioned (Azure) Load Balancer  [External LB IP, spec.ports.port] (svc type is LB) XOR LB not operated by k8s XOR NO LB
->  Worker Node [1 WorkerNode IP, hostPort] -> DNAT rules generated (ipTable update by portMap CNI plugin) to (podId, podTemplate.spec.ports.containerPort)
-> [podIp, podTemplate.spec.ports.containerPort] distributing to the Ingress POD of the reached node 
````

Note the usage of container port in podTemplate and not of service, which here is not for documentation, 
More details on hostPort here: https://lambda.mu/hostports_and_hostnetwork/

Usually privileged port is used 80/443.

#### Wrap together : Ingress possibilities

[Northbound with (option A or B)](#client-to-ingress-itself-is-a-using-standard-k8s-service-but-it-can-also-bind-port-on-node-) + [southbound](#traefik-to-pod)

#### Comments

In front of the load balancer we can have a DNS.
This DNS entry can be conveyed in the host header. This host header can be used by the ingress policy to identify the correct ingress rule to be applied.
We can replace the load balancer by a round-robin DNS.
In northbound part, LB is doing L3 routing whereas ingress is L7.

Here: https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-f.md
We describe similar without load balancer, using Minikube ingress and NAT.


#### SPOF: Single Point Of Failure 
<!-- above was ok -->

To avoid SPOF, we load balance on all nodes where Traefik is running (all if [daemonset](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset)) which then redispatch to a pod potentially in different node?
(or DNS load balancing)

See this question: 
https://stackoverflow.com/questions/60031377/load-balancing-in-front-of-traefik-edge-router

### OpenShift route (HA proxy)

OpenShift Route is equivalent to Ingress
Cf. this [OpenShift blogpost](https://blog.openshift.com/kubernetes-ingress-vs-openshift-route/)
From [OpenShift HA proxy doc](https://docs.okd.io/latest/architecture/networking/assembly_available_router_plugins.html#architecture-haproxy-router):
> The template router has two components:
> - A wrapper that watches endpoints and routes and causes a HAProxy reload based on changes
> - A controller that builds the HAProxy configuration file based on routes and endpoints

See this documentation: https://docs.redhat.com/en/documentation/openshift_container_platform/3.5/html/installation_and_configuration/setting-up-a-router

OpenShift router use [option B](#option-b-bind-a-port-in-node). 

Evidence in this doc: https://docs.redhat.com/en/documentation/openshift_container_platform/3.5/html/installation_and_configuration/setting-up-a-router#deploy-router-create-router

```text
oc get po <router-pod>  --template={{.status.hostIP}}
```

Also the F5 itself can be used as an Ingress: https://docs.redhat.com/en/documentation/openshift_container_platform/3.5/html/installation_and_configuration/setting-up-a-router#f5-configuring-the-virtual-servers

I will nor not enter into the details, this deprecated doc is [documenting (past?) integration](k8s_f5_integration.md))

### More details on Ingress configuration with Minikube

I this post we did a deep deep dive of Minikube ingress based on [Nginx ingress](https://github.com/kubernetes/website/issues/26137):
https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-0.md (from part f).
with certificate management.

<!-- which is completed (and referenced in post) with a deep-dive on OpenShift route: https://github.com/scoulomb/private_script/tree/main/sei-auto --> https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip


-----
# Other ways to access a service

Note in previous experience we were using a real Kubernetes distribution with Nginx ingress.
Here we use Minikube with ingress add-ons

<!--
Auth using wpa or service button
- Configure NAT
http://192.168.1.1/network/nat
ssh 	TCP 	Port 	22 	192.168.1.32 	22
- Get your public IP
http://192.168.1.1/state/wan	
109.29.148.109
-->

## hostNetwork: true

### Try to deploy a pod with hostNetwork


**This is exactly what we used with bind ingress, see [](#cloud-edgeand-pop)

````shell script
ssh sylvain@109.29.148.109
alias k='sudo kubectl'
k create deployment deploy1 --image=nginx --dry-run -o yaml

echo 'apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: deploy1
  name: deploy1-hostnetwork
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deploy1
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: deploy1
    spec:
      hostNetwork: true # Note hostNetwork here
      containers:
      - image: nginx
        name: nginx
        resources: {}' > deploy1-hostnetwork.yaml

k apply -f deploy1-hostnetwork.yaml
````

### Port 80 could be already in use by another process

So if we curl 

````shell script
 curl --silent http://localhost 
````

````shell script
sylvain@sylvain-hp:~$  curl --silent http://localhost
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.17.10</center>
</body>
</html>
````


here we actually target the ingress (which is using host port , see below).
And pod will crashloopback off as port 80 is already in use.

````shell script
sylvain@sylvain-hp:~$ k get deploy
NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
deploy1-hostnetwork   0/1     1            0           14m

ylvain@sylvain-hp:~$ k logs deploy1-hostnetwork-6c6d594544-h2ck4
[...]
2021/01/29 08:42:18 [emerg] 1#1: bind() to [::]:80 failed (98: Address already in use)
nginx: [emerg] bind() to [::]:80 failed (98: Address already in use)
2021/01/29 08:42:18 [emerg] 1#1: still could not bind()
nginx: [emerg] still could not bind()
````


### A normal deployment would work

````shell script
k create deployment deploy1-normal --image=nginx
curl $(k get po -o wide | grep "deploy1-normal-" | awk '{print $6}') | head -n 5
````

output is 

````shell script
sylvain@sylvain-hp:~$ curl $(k get po -o wide | grep "deploy1-normal-" | awk '{print $6}') | head -n 5
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   597k      0 --:--:-- --:--:-- --:--:--  597k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
````

### To make hostNetwork work, we will disable the ingress.

````shell script
sudo minikube addons disable ingress
k delete deploy deploy1-hostnetwork
k apply -f deploy1-hostnetwork.yaml
````
So that we can curl

````shell script
curl --silent http://localhost 
````

therefore output is 

````shell script
sylvain@sylvain-hp:~$ curl --silent http://localhost | head -n 5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
````

### What happens if I scale

````shell script
k scale deployment deploy1-hostnetwork --replicas=3
````

As we can use only one port 

````shell script
sylvain@sylvain-hp:~$ k get po | grep deploy1-hostnetwork-
deploy1-hostnetwork-6c6d594544-4f7zn   1/1     Running            0          7m40s
deploy1-hostnetwork-6c6d594544-cdfzv   0/1     CrashLoopBackOff   2          55s
deploy1-hostnetwork-6c6d594544-kpgg2   0/1     CrashLoopBackOff   2          55s
sylvain@sylvain-hp:~$ k logs deploy1-hostnetwork-6c6d594544-cdfzv | tail -n 4
2021/01/29 10:17:39 [emerg] 1#1: bind() to [::]:80 failed (98: Address already in use)
nginx: [emerg] bind() to [::]:80 failed (98: Address already in use)
2021/01/29 10:17:39 [emerg] 1#1: still could not bind()
nginx: [emerg] still could not bind()
````

### Clean-up and restore ingress

````shell script
k delete deploy deploy1-hostnetwork
k delete deploy deploy1-normal
sudo minikube addons enable ingress
````

Looking at: https://learn.microsoft.com/en-us/azure/aks/concepts-network-ingress#ingress-controllers, we understand well and see simplification made! (forked here: https://github.com/scoulomb/azure-aks-docs/blob/main/articles/aks/concepts-network-ingress.md)


## Host port

Flow is 

````
Worker Node [1 WorkerNode IP, hostPort] -> DNAT rules generated (ipTable update by portMap CNI plugin) to (podId, podTemplate.spec.ports.containerPort)
-> [podIp, podTemplate.spec.ports.containerPort] distributing to the Ingress POD of the reached node 
````

See https://lambda.mu/hostports_and_hostnetwork/


This is what is actually used by [ingress when it is binded to the node](#option-b-bind-a-port-in-node)

where we 

> bind ingress controller on each node directly to port 80/443

### Try to deploy a pod with host port

````shell script
ssh sylvain@109.29.148.109
alias k='sudo kubectl'

echo 'apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: deploy1
  name: deploy1-hostport
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deploy1
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: deploy1
    spec:
      containers:
      - image: nginx
        name: nginx
        ports:
          - containerPort: 80 # if removed missing required field "containerPort" even without hostNetwork
            hostPort: 80
        resources: {}' > deploy1-hostport.yaml

k apply -f deploy1-hostport.yaml
````

### Port 80 could be already in use by another process

So if we curl 

````shell script
curl --silent http://localhost 
````

````shell script
sylvain@sylvain-hp:~$  curl --silent http://localhost
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.17.10</center>
</body>
</html>
````


here we actually target the ingress (which is using host port , see below).
And pod will crashloopback off as port 80 is already in use.

````shell script
k get deploy
k get po | grep deploy1-hostport
k describe po $(k get po | grep deploy1-hostport | awk '{print $1}') | grep -A 3 Events
````

output is 


````shell script
sylvain@sylvain-hp:~$ k get deploy
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
deploy1-hostport   0/1     1            0           118s
sylvain@sylvain-hp:~$ k get po | grep deploy1-hostport
deploy1-hostport-665b55679b-kx5gl   0/1     Pending   0          2m1s
sylvain@sylvain-hp:~$ k describe po $(k get po | grep deploy1-hostport | awk '{print $1}') | grep -A 3 Events
Events:
  Type     Reason            Age        From               Message
  ----     ------            ----       ----               -------
  Warning  FailedScheduling  <unknown>  default-scheduler  0/1 nodes are available: 1 node(s) didn't have free ports for the requested pod ports.
`````

Here the pod is not scheduled (so it does not go through the log steps).

### A normal deployment would work

````shell script
k create deployment deploy1-normal --image=nginx
curl $(k get po -o wide | grep "deploy1-normal-" | awk '{print $6}') | head -n 5
````

output is 

````shell script
sylvain@sylvain-hp:~$ curl $(k get po -o wide | grep "deploy1-normal-" | awk '{print $6}') | head -n 5
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   597k      0 --:--:-- --:--:-- --:--:--  597k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
````

### To make hostPort work, we will disable the ingress.

````shell script
sudo minikube addons disable ingress
k delete deploy deploy1-hostport
k apply -f deploy1-hostport.yaml
````
So that we can curl

````shell script
curl --silent http://localhost | head -n 5
````

therefore output is 

````shell script
sylvain@sylvain-hp:~$ curl --silent http://localhost | head -n 5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
````

### What happens if I scale

````shell script
k scale deployment deploy1-hostport --replicas=3
k get po | grep deploy1-hostport-
k describe po $(k get po -o wide | grep "deploy1-hostport-" | grep Pending | head -n 1 | awk '{print $1}' ) |  grep -A 3 Events
````

As we can use only one port 

````shell script
sylvain@sylvain-hp:~$ k get po | grep deploy1-hostport-
deploy1-hostport-665b55679b-8k2mb   1/1     Running   0          5m22s
deploy1-hostport-665b55679b-9t627   0/1     Pending   0          4m44s
deploy1-hostport-665b55679b-fqh9s   0/1     Pending   0          4m44s
sylvain@sylvain-hp:~$ k describe po $(k get po -o wide | grep "deploy1-hostport-" | grep Pending | head -n 1 | awk '{print $1}' ) |  grep -A 3 Events
Events:
  Type     Reason            Age        From               Message
  ----     ------            ----       ----               -------
  Warning  FailedScheduling  <unknown>  default-scheduler  0/1 nodes are available: 1 node(s) didn't have free ports for the requested pod ports.
sylvain@sylvain-hp:~$
````


### Clean-up and restore ingress

````shell script
k delete deploy deploy1-hostport
k delete deploy deploy1-normal
sudo minikube addons enable ingress
````

### Impact on scheduling

Note container port can impact scheduling:
`0/1 nodes are available: 1 node(s) didn't have free ports for the requested pod ports.`

### ContainerPort unlike hostPort can make port forwarding

See documenttion from the Kubectl

````shell script
sylvain@sylvain-hp:~$  k explain pod.spec.containers.ports
KIND:     Pod
VERSION:  v1

RESOURCE: ports <[]Object>

DESCRIPTION:
     List of ports to expose from the container. Exposing a port here gives the
     system additional information about the network connections a container
     uses, but is primarily informational. Not specifying a port here DOES NOT
     prevent that port from being exposed. Any port which is listening on the
     default "0.0.0.0" address inside a container will be accessible from the
     network. Cannot be updated.

     ContainerPort represents a network port in a single container.

FIELDS:
   containerPort        <integer> -required-
     Number of port to expose on the pod's IP address. This must be a valid port
     number, 0 < x < 65536.

   hostIP       <string>
     What host IP to bind the external port to.

   hostPort     <integer>
     Number of port to expose on the host. If specified, this must be a valid
     port number, 0 < x < 65536. If HostNetwork is specified, this must match
     ContainerPort. Most containers do not need this.
[...]
````

Thus if I do

````shell script
echo 'apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: deploy1
  name: deploy1-hostport
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deploy1
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: deploy1
    spec:
      containers:
      - image: nginx
        name: nginx
        ports:
          - containerPort: 80 # if removed missing required field "containerPort"
            hostPort: 7777
        resources: {}' > deploy1-hostport-with-fw.yaml

k apply -f deploy1-hostport-with-fw.yaml
````

if we do

````shell script
curl localhost:7777
````

output is

````shell script
sylvain@sylvain-hp:~$ curl localhost:7777 | head -n 5
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   597k      0 --:--:-- --:--:-- --:--:--  597k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
````


## Use hostPort and hostNetwork together

````shell script
echo 'apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: deploy1
  name: deploy1-hostnetwork-and-port
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deploy1
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: deploy1
    spec:
      hostNetwork: true # Note hostNetwork here
      containers:
      - image: nginx
        name: nginx
        ports:
          - containerPort: 80 # if removed missing required field "containerPort"
            hostPort: 7777
        resources: {}' > deploy1-hostnetwork-and-port

k apply -f deploy1-hostnetwork-and-port
````

output is

````shell script
The Deployment "deploy1-hostnetwork-and-port" is invalid: spec.template.spec.containers[0].ports[0].containerPort: Invalid value: 80: must match `hostPort` when `hostNetwork` is true
````

Thus this will work

````shell script
echo 'apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: deploy1
  name: deploy1-hostnetwork-and-port
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deploy1
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: deploy1
    spec:
      hostNetwork: true # Note hostNetwork here
      containers:
      - image: nginx
        name: nginx
        ports:
          - containerPort: 80 # if removed missing required field "containerPort"
            hostPort: 80
        resources: {}' > deploy1-hostnetwork-and-port

sudo minikube addons disable ingress
k apply -f deploy1-hostnetwork-and-port
curl localhost:80 | head -n 5
````

output is 

````shell script
sylvain@sylvain-hp:~$ curl localhost:80 | head -n 5
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   597k      0 --:--:-- --:--:-- --:--:--  597k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
````

## kubectl port forwarding and proxy

Those are shown here: https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/container-port.md#is-it-an-issue-to-not-have-the-containerport
We also show in which circumstances container port can be used.

<!-- 
here: https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/container-port.md#adding-containerport-to-7777
could force the port and typo //, stop here -->



-----
# Other examples

## In my DNS

In this script we use various way to access DNS as shown here:
https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-docker-bind-dns-use-linux-nameserver-rather-route53/6-use-linux-nameserver.sh

## Link with Ales Nosek blogpost

In this article: https://alesnosek.com/blog/2017/02/14/accessing-kubernetes-pods-from-outside-of-the-cluster/.
Which is mirrored [here](./resources/alesnosek-blogpost.md).

They talked on different way to 
> Accessing Kubernetes Pods from Outside of the Cluster

They use:
- [hostNetwork: true](resources/alesnosek-blogpost.md#hostnetwork-true)
- [hostPort](resources/alesnosek-blogpost.md#hostport):
We also mentioned it is used by Ingress.
- [NodePort](resources/alesnosek-blogpost.md#nodeport)
In [spof section](#when-using-nodeport)  we also mention we can load balance manually.
- [LoadBalancer](resources/alesnosek-blogpost.md#loadbalancer)
- [Ingress](resources/alesnosek-blogpost.md#ingress):
> - In the case of the LoadBalancer service, the traffic that enters through the external load balancer is forwarded to the kube-proxy that in turn forwards the traffic to the selected pods.
> - In contrast, the Ingress load balancer forwards the traffic straight to the selected pods which is more efficient.

See same comment in [spof section](#single-point-of-failure) where we also mentioned ingress watch directly endpoint.
2nd quote is really true  with what we call "with Alternative (2+3)".

<!-- post clear and ingress quote actually OK-->

<!-- ssl termination is discussed 
https://github.com/scoulomb/private_script/ in certificate.md
where it is at ingress, pod level but could be at lb -->

---
# Understanding the internals

See [Appendix on internals](appendix_internals.md).

---
# Global Summary

To access to an OpenShift cluster (externally) we can use

- [clusterIP](#clusterip): internal only

- [hostPort](#host-port)

  `````text
  Worker Node [1 WorkerNode IP, hostPort] -> DNAT rules generated (ipTable update by portMap CNI plugin) to (podId, podTemplate.spec.ports.containerPort)
  -> [podIp, podTemplate.spec.ports.containerPort] distributing to the Ingress POD of the reached node 
  `````

- [NodePort service](#nodeport--clusterip--high-routed-port)
  
  ````
  External Traffic -> Worker Node [1 WorkerNode IP, spec.ports.NodePort] -> DNAT rules generated from Kube-Proxy using (svc.ports.NodePort) to (podId, spec.ports.TargetPort) ->[podIp, spec.ports.TargetPort] distributing to set of PODs  
  ````

See note on [external traffic policy](#note-on-external-traffic-policy) 

- [LoadBalancer service](#loadbalancer--nodeport--lb) (where LB svc type super set nodePort)
  
  ````
  External Traffic -> Provisioned Azure Load Balancer  [External LB IP, spec.ports.port] ->  Worker Node [1 WorkerNode IP, spec.ports.NodePort] -> DNAT rules generated from Kube-Proxy using (svc.ports.NodePort) to (podId, spec.ports.TargetPort) -> [podIp, spec.ports.TargetPort] distributing to set of PODs  
  ````
  
  Alternative is to use a NodePort and do own load balancing manually, it is equivalent to load balancer type, except that LB will not be automatically provisioned.
  Provisioned means platform Provisioned.


- [Ingress](#implementation-details)
  - Northbound
    - [Option A](#option-a-use-nodeport-): which uses NodePort/LoadBalancer service type (see bullet above)

          ````
          External Traffic ->  Provisioned (Azure) Load Balancer  [External LB IP, spec.ports.port] (svc type is LB) XOR LB not operated by k8s XOR NO LB
          ->  Worker Node [1 WorkerNode IP, spec.ports.NodePort] -> DNAT rules generated from Kube-Proxy using (svc.ports.NodePort) to (podId, spec.ports.TargetPort)
          -> [podIp, spec.ports.TargetPort] distributing to set of Ingress PODs 
          ````
  

    - [Option B](#option-b-bind-a-port-in-node): which uses hostPort (see bullet above)

          ````
          External Traffic ->  Provisioned (Azure) Load Balancer  [External LB IP, spec.ports.port] (svc type is LB) XOR LB not operated by k8s XOR NO LB
          ->  Worker Node [1 WorkerNode IP, hostPort] -> DNAT rules generated (ipTable update by portMap CNI plugin) to (podId, podTemplate.spec.ports.containerPort)
          -> [podIp, podTemplate.spec.ports.containerPort] distributing to the Ingress POD of the reached node 
          ````
  - Southbound
        
      ````text
      Southbound: -> Ingress pod is applying rules defined in Ingress resource. It select a k8s service. We call it selectedSvc in this doc (**) -> [podIp, selectedSvc.ports.TargetPort] distributing to set of PODs IP (matching svc label)
      ````

We also understand simplification made here
- https://github.com/scoulomb/azure-aks-docs/blob/main/articles/aks/concepts-network-services.md
- https://github.com/scoulomb/azure-aks-docs/blob/main/articles/aks/concepts-network-ingress.md
<!-- ok suffit yes, and quick check consistent stop -->

Note: we can have dedicated HA proxy node for an application

We can have platform HA proxy node <!-- infra nodes --> or dedicated HA proxy node.

So we can access cluster via 3 ways <!-- impact here: /private_script blob /Links-mig-auto-cloud/listing-use-cases/listing-use-cases-appendix-0-deep-dive-on-sharding.md#ingress-and-nodeport -->
1. NodePort
2. Ingress (option A or option B) 
  - 2.1 Platform HA proxy nodes
  - 2.2 Dedicated nodes


See link with: private_script/ Links-mig-auto-cloud/listing-use-cases/listing-use-cases-appendix-0-deep-dive-on-sharding.md#ingress-and-nodeport

# Facade in front of Azure LB

## [Point of Presence](https://en.wikipedia.org/wiki/Point_of_presence) / Cloud edge

If we have a [cloud Point Of Presence](https://en.wikipedia.org/wiki/Point_of_presence) (customer traffic), here we talk only about an app instance part <!-- shard --> <!-- located in: non cloud DC or cloud provider Azure, AWS, GCP... -->.
We could have another F5 in POP cloud edge in front of LB in section above. <!--  LB is in | non cloud DC: F5, Azure: Azure LB -->.

This cloud edge LB could target right instance (via TM when Azure)<!-- Search "granularity" / Links-mig-auto-cloud/listing-use-cases/listing-use-cases-appendix-0-deep-dive-on-sharding.md -->.
<!-- Azure | ESB: case of NodePort, Apigee: case of Ingress (which can re-target "Azure" (this comment) via cloud edge or "Non cloud DC" (comment below) or cloud native app) . Both Azure ESB/Apigee LB is a provisioned Azure LB via LoadBalancer k8s service type-->

<!-- non cloud DC | ESB: F5 to VM MUX (no openshift), Apigee: case of Ingress with NodePort service type and F5 LB, F5 LB not provisioned by k8s -->

Remind that Ingress can do routing based on host header which is usually the DNS in front of (Azure) load balancer
<!-- Azure | Apigee Azure technical DNS for instance -->

**See strong link with private script listing-use-cases/listing-use-cases-appendix-1- (schema with port) and appendix-2**

<!-- see also https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-Host -->

## Internal traffic, ingress example

Assume we have Ingress with Option A, with LoadBalancer service provisioning an Azure load balancer.
This will give us an IP address.

Usually a wildcard DNS record is defined to this Azure Load Balancer IP:  `*.mypass.toto.net`
A default paas openshift route (OpenShift router is an implem of HA proxy) is created, and it matches `something.mypass.toto.net`. Client targeting DNS will be distributed to HA proxy PODs (with option A [`NodePort`](#nodeport--clusterip--high-routed-port), HA proxy pod can be in different node as the one receiving request), and HA proxy can select the correct service based on the rule (and here pod can be again in different node).
<!-- in some implem route name may be auto filled with service name + wildcard -->

We could block direct access to the route, from a given network zone (for example office to prod)
Thus we would have to go through a reverse proxy / [Azure Application Gateway](https://learn.microsoft.com/en-us/azure/application-gateway/overview) (not apim or LB Layer 4) (doc describes it as something very similar to HA proxy) / [AWS application load balancer](https://learn.microsoft.com/fr-fr/azure/architecture/aws-professional/networking)....

Reverse proxy example is HA proxy: https://github.com/scoulomb/myhaproxy/blob/main/README.md

In that case we will need to define an entry
- DNS to HA proxy front-end 
- Entry (backend) in reverse proxy (https://github.com/scoulomb/myhaproxy/blob/main/haproxy/haproxy.cfg) to Azure Load Balancer IP (we can use wildcard DNS)
- OpenShift route matching DNS in front of HA proxy so that Ingress/OpenShift HA proxy can select correct service

<!-- tm discussion - 3-9-24 - and consistent OK .status.loadbalancer.ingress.[].ip of Ingress svc matches az lb ip, this az lb IP is returned by nslookup of DNS `*.mypass.toto.net` (even if TNZ in name, just zone, not the DNS to proxy OK)  (IP returned is not the one of nodes) -->

We would have the following rational 
- Access API inside cluster (like non reg) to target clusterIP (via [svc dns](#svc-discovery-by-environment-variable-or-dns-within-a-pod) directly of service which would have been selected by Ingress, We called it `selectedSvc` in Ingress/Southbound. 
- Access API in same nw zone to use wildcard DNS of platform
- User outside of cluster (in different network zone ) to use reverse proxy, gateway

In that case we would have this HA proxy + kube-proxy + platform HA proxy ;) 
See comment at https://github.com/scoulomb/myhaproxy/blob/main/README.md#k8s-and-ha-proxy <!-- align OK https://github.com/scoulomb/myhaproxy/commit/37c17c877dcd012477a6066bc7a54aca58c2720e -->

<!-- non cloud DC paas similar, LB here is Azure LB in Azure, non cloud and different provider, other solution and not necessarily a F5 in non cloud: https://github.com/scoulomb/private_script/blob/7b55c023a0859413b6336edde3a686613b3549d8/Links-mig-auto-cloud/certificate-management-in-cloud.md -->

<!-- OK FULL DOC CLEAN AND CCL OK CCL 3sep24 -->
<!-- I can refully concluded OK - YES CCL OK -->

--
# Re-encryption when route is used

- https://github.com/scoulomb/misc-notes/blob/master/tls/tls-certificate.md#complements -> https://docs.openshift.com/container-platform/4.7/networking/routes/secured-routes.html
- We can have at Ingress / OpenShift route level re-encrypt, edge, and passthrough routes with custom certificates 
- re-encrypt and edge can benefit from platform default certificate 
- See example of re-encrypt: https://github.com/scoulomb/private_script/blob/7b55c023a0859413b6336edde3a686613b3549d8/Links-mig-auto-cloud/certificate-doc/SSL-certificate-as-a-service-on-Openshift-4.md?plain=1#L16
  - We have certificate exposed by router (usually trusted by client)
  - We re-encrypt with certificate (which is signed by a private CA, trusted by the the OpenShift router client). The certificate signed by private CA offloaded in POP (can be via a sidecar or not)

- Other components in the chain ([Facade](#facade-in-front-of-azure-lb) and Apigee) which can perform cert management with: `edge`, `passthrough` and `re-encrypt` capabilities. 
  - Does not offer
    - Azure load balancer is L4 so it does not re-encrypt or offer TLS management: https://www.reddit.com/r/AZURE/comments/156t9q8/is_there_any_way_to_do_ssl_termination_for_azure/
    <!-- non cloud DC F5 tls added in cloudfi, when IP move in cloud edge, re-encrypt done in cloud edge independent if target in legacy (here tls removed, passthrough) or azure -->
  - Offers
    - [Azure Application Gateway for facade internal traffic](#internal-traffic-ingress-example) used for [Internal traffic](#service-internal), 
    - [F5 used in Facade edge](#point-of-presence--cloud-edge) : https://my.f5.com/manage/s/article/K65271370 - [local copy](./resources/Most%20Common%20SSL%20Methods%20for%20LTM%20SSL%20Offload,%20SSL%20Pass-Through%20and%20Full%20SSL%20Proxy.pdf)
    - Apigee could use [Ingress](#global-summary) - kind of facade - [See Apigee comment in section](#facade-in-front-of-azure-lb) <!-- link with appendix-2 @listing-use-cases/listing-use-cases-appendix-1- and appendix-2, apigee => ESB -->

<!--  note L4 azure LB vs L3 router: CLB vs ALB vs NLB | Choosing the right AWS Load Balancer: https://www.site24x7.com/learn/clb-vs-alb-vs-nlb.html
@PrezNewGen: difference IP switch and network path
-->

--
#  Tan 

- p 762 (739): Server farms vs webproxies  
  - Server farm: mention alternative to use round robin DNS instead of LB (apply to all above)
- p 767 (743) CDN (relying on GEO DNS) <!-- GDA - stop there - appendix-1 in listing-use-cases private script -->
