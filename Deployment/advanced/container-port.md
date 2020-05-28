# Service port and container port 

This is a complement to Master Kubectl [section](../../Master-Kubectl).

## Create pod with service and container port 

When using `kubectl run` to create a pod:

````buildoutcfg
 k run nginx --image=nginx --restart=Never --port=80 --expose --dry-run -o yaml
````

Output is:

````shell script
➤ k run nginx --image=nginx --restart=Never --port=80 --expose --dry-run -o yaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  name: nginx
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    run: nginx
status:
  loadBalancer: {}
---
---
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: nginx
  name: nginx
spec:
  containers:
  - image: nginx
    name: nginx
    ports:
    - containerPort: 80
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}
````

Port is used for:
- `k explain pod.spec.containers.ports.containerPort`
- `k explain service.spec.ports.port`

Note port=targetPort (`k explain service.spec.ports.targetPort`) by default.
If `expose` is not set, service is not created.
Note the list of resource as in explain in [here](../../Master-Kubectl/here-doc.md).

But can not use `expose` without `port`. 

## Create deployment with service and container port 

### Older version 

(<1.18) 

````buildoutcfg
 k run nginx --image=nginx --restart=Always --port=80 --expose --dry-run -o yaml
````
Output is

````shell script
➤ k run nginx --image=nginx --restart=Always --port=80 --expose --dry-run -o yaml

kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: null
  name: nginx
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    run: nginx
status:
  loadBalancer: {}
---
---
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    run: nginx
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      run: nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        run: nginx
    spec:
      containers:
      - image: nginx
        name: nginx
        ports:
        - containerPort: 80
        resources: {}
status: {}
````

### Using kubectl apply

https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#creating-a-deployment

Where we can take previous manifest 

### Using kubectl create deployment 

As seen here in [k8s note](https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md#create-deployment)

````shell script
k create deployment alpine-deployment --image=alpine --dry-run -o yaml -- echi
````

However for deployment we can not give a command unlike `k run` and `k create` for some resource.
As show here: Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md#discrepancy-between-k-run-and-k-create

Same for number of replicas.

In order to recreate the same results as:
https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#creating-a-deployment

<!-- Update doc -> No -->

We should do

````shell
k delete deployment --all
k create deployment nginx-deployment --image=nginx:1.14.2 
k scale deployment nginx-deployment --replicas=3 --record 
k patch deployment nginx-deployment --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports", "value": [ { "containerPort": 80 } ] }]' --record
````

Note all of this in 2 version (replicas does not trigger a version)
To see this I used `--record` option.

````shell script
➤ k get rs                                                                       vagrant@archlinux
NAME                          DESIRED   CURRENT   READY   AGE
nginx-deployment-5684d7c768   3         3         3       8s
nginx-deployment-67dbb7656f   0         0         0       27s
[09:51] ~
➤ k rollout history deployment.v1.apps/nginx-deployment                          vagrant@archlinux
deployment.apps/nginx-deployment
REVISION  CHANGE-CAUSE
1         kubectl scale deployment nginx-deployment --replicas=3 --record=true
2         kubectl patch deployment nginx-deployment --type=json --patch=[{"op": "add", "path": "/spec/template/spec/containers/0/ports", "value": [ { "containerPort": 80 } ] }] --record=true
````

Modulo the label exactly same deployment
Did not try file option OK

We can create a service doing 

````shell script
k expose deployment nginx-deployment
````

If we do not patch with containerPort we should do

````shell script
k expose deployment nginx-deployment --port=80
````

But this will not create a containerPort in the deployment.

Output is 

````shell script
➤ k get svc | grep nginx-deployment                                           vagrant@archlinux
nginx-deployment   ClusterIP   10.96.27.102     <none>        80/TCP     16s
````


## Is it an issue to not have the containerPort?


### WITHOUT containerPort

````shell script
k delete deployment,svc --all
k create deployment nginx-deployment --image=nginx:1.14.2 
k scale deployment nginx-deployment --replicas=3 --record 
k expose deployment nginx-deployment --port=80
````

- We can exec into the pod and do a curl

- we can use pod ip

````shell script
# or k get pods -o wide
export pod_ip=(k get pod nginx-deployment-6695676c48-l8krk -o jsonpath='{.status.podIP}{"\n"}')
curl $pod_ip:80
````

Output is

````shell script
➤ curl $pod_ip:80                                                             vagrant@archlinux<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
````
- We can target svc from node

````shell script
export svc_ip=(k get svc nginx-deployment -o jsonpath='{.spec.clusterIP}{"\n"}')
curl $svc_ip:80
````

Output is 

````shell script
➤ curl $svc_ip:80                                                             vagrant@archlinux<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
````

- can target svc from another pod

````shell script
k run --rm -it --image=busybox --restart=Never -- bash wget -O- nginx-deployment:80
````

Output is 

````shell script
➤ k run --rm -it --image=busybox --restart=Never -- bash wget -O- nginx-deployment:80

Connecting to nginx-deployment:80 (10.110.115.177:80)
writing to stdout
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
````

Then see service [section](../../Services/service_deep_dive.md)

Note DNS name only working from a pod but not a node.
Cluster IP working from both.


- We can use port forwarding
https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/

It can be to a pod, deployment (this does not use service, if not present we can see it is not created. It is based on label)
Port forwarding can be used to a service.

````shell script
# Window 1
➤ k port-forward deployment/nginx-deployment 7000:80 &                        vagrant@archlinuxForwarding from 127.0.0.1:7000 -> 80
Forwarding from [::1]:7000 -> 80
Handling connection for 7000
Handling connection for 7000

# Window 2 
➤ curl 127.0.0.1:7000                                                         vagrant@archlinux<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
````

If we have an error

````shell script
Handling connection for 7000
E0528 18:26:25.587634  195919 portforward.go:400] an error occurred forwarding 7000 -> 80: error forwarding port 80 to pod 69b062dfd5907bbb3065f06efca5388fc761a0d3df0d0698cbf73bc039327288, uid : unable to do port forwarding: socat not found
Handling connection for 7000
````

Do 

````shell script
➤ sudo pacman -S socat
````



- Using kubectl proxy

https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#using-kubectl-proxy

````shell script
k proxy --port=8080 # Launch with sudo on minikube oterwise 401 error 
````

Then in another window

````shell script
curl http://localhost:8080/api/
````


Then as suggested here: https://livebook.manning.com/book/kubernetes-in-action/chapter-10/140

````shell script
➤ curl -L http://localhost:8080/api//v1/namespaces/default/pods/nginx-deployment-6695676c48-22qs2/proxy/
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
````

<!--
see nwa-sre-setup
-->

### ADDING containerPort to 7777

````shell script
k patch deployment nginx-deployment --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports", "value": [ { "containerPort": 7777 } ] }]' --record
````

All methods are working except Kubectl proxy (as guessed!)

````shell script
➤ curl -L http://localhost:8080/api//v1/namespaces/default/pods/nginx-deployment-6b9ccbbbd5-jdpb7/proxy/
Error trying to reach service: 'dial tcp 172.17.0.4:7777: connect: connection refused'⏎
````


Note on proxy here: https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#so-many-proxies
Port fw not included in that.

<!--
Link to CKAD exo (C-Pod design, Using kubectl to create deployment )
OK STOP
-->