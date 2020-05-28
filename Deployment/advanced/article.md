# Deployment tutorial


## Prepare environment 

- Start Minikube

````shell script
bash
sudo minikube start --vm-driver=none
````


- Define alias and clean-up

See k8s [documentation](https://kubernetes.io/fr/docs/reference/kubectl/cheatsheet/).

````shell script
source <(kubectl completion bash) # active l'auto-complétion pour bash dans le shell courant, le paquet bash-completion devant être installé au préalable
echo "source <(kubectl completion bash)" >> ~/.bashrc # ajoute l'auto-complétion de manière permanente à votre shell bash

alias k='sudo kubectl' # Add sudo
complete -F __start_kubectl k

k delete deployment --all
k delete rs --all
k delete pod --all
k delete svc --all
````

- Build the 4 different version of the sample app

See sample app [README](./sample-app/README.md).

## Deploy first version
````shell script
k create deployment server --image=server:v1 --dry-run -o yaml
# use `k create deployment` form without save-config option leads to a warning when doing k apply -
# f to update the deployment; as I will change the image pull policy I will export a YAML and apply it.
````

We will use imagePullPolicy to Never to use locally built image

````shell script
# k explain pod.spec --recursive | grep -i -C 10 pull
[vagrant@archlinux sample-app]$ k explain pod.spec.containers.imagePullPolicy
KIND:     Pod
VERSION:  v1

FIELD:    imagePullPolicy <string>

DESCRIPTION:
     Image pull policy. One of Always, Never, IfNotPresent. Defaults to Always
     if :latest tag is specified, or IfNotPresent otherwise. Cannot be updated.
     More info:
     https://kubernetes.io/docs/concepts/containers/images#updating-images
````

So the deployment will be 


````shell script
cat << EOF | k apply -f - --record
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: server
  name: server
spec:
  replicas: 3 ##
  selector:
    matchLabels:
      app: server
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: server
    spec:
      containers:
      - image: server:v1
        imagePullPolicy: Never ## 
        name: server
        resources: {}
status: {}
EOF
k get deploy,rs,po && echo -e "-----\n"   && k rollout status deployment server

````


Output is:


````shell script
[vagrant@archlinux ~]$ k get deploy,rs,po && echo -e "-----\n"   && k rollout status deployment server
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/server   0/3     3            0           0s

NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/server-f9999df48   3         3         0       0s

NAME                         READY   STATUS              RESTARTS   AGE
pod/server-f9999df48-67zw4   0/1     ContainerCreating   0          0s
pod/server-f9999df48-lc7rz   0/1     ContainerCreating   0          0s
pod/server-f9999df48-rmj6n   0/1     ContainerCreating   0          0s
-----

Waiting for deployment "server" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "server" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "server" rollout to finish: 2 of 3 updated replicas are available...
deployment "server" successfully rolled out
````

We can understand rs label matching with pod by doing:

````shell script
pod_0_name=$(k get po -o jsonpath='{.items[0].metadata.name}')
rs_name=$(k get rs -o jsonpath='{.items[0].metadata.name}')
echo $pod_0_name
echo $rs_name
k get pod  $pod_0_name -o  jsonpath='{.metadata.labels}{"\n"}'
k get replicaset  $rs_name -o jsonpath='{.spec.selector.matchLabels}{"\n"}'
````

Output is

````shell script
[vagrant@archlinux ~]$ k get pod  $pod_0_name -o  jsonpath='{.metadata.labels}{"\n"}'
map[app:server pod-template-hash:f9999df48]
[vagrant@archlinux ~]$ k get replicaset  $rs_name -o jsonpath='{.spec.selector.matchLabels}{"\n"}'
map[app:server pod-template-hash:f9999df48]
````

And could create mess if creating a pod matching this labels (already tested ok)

## Create a service to deploy the pod

````shell script
k expose deployment server --port=8080
k get svc
````

Output is 

````shell script
[vagrant@archlinux ~]$ k expose deployment server --port=8080
service/server exposed
[vagrant@archlinux ~]$ k get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP    3m53s
server       ClusterIP   10.96.190.252   <none>        8080/TCP   14s
````

And use it

````shell script
cat << EOF > status.sh
# use sudo to go to root profile, no default user plugged to other PAAS
export server_ip=$(sudo kubectl get svc server -o jsonpath='{.spec.clusterIP}{"\n"}')
while true; do sudo kubectl get rs && sudo kubectl rollout status deployment server --watch=false && curl -i $server_ip:8080/api/v1/time && sleep 5; done
EOF
chmod 770 status.sh
./status.sh
````

Output is 

````shell script

[vagrant@archlinux ~]$ ./status.sh
NAME               DESIRED   CURRENT   READY   AGE
server-f9999df48   3         3         3       4m47s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:39:39 GMT

{"hostname":"server-f9999df48-lc7rz","time":"11:39:39","version":1}
NAME               DESIRED   CURRENT   READY   AGE
server-f9999df48   3         3         3       4m52s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:39:44 GMT

{"hostname":"server-f9999df48-67zw4","time":"11:39:44","version":1}
NAME               DESIRED   CURRENT   READY   AGE
server-f9999df48   3         3         3       4m57s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:39:49 GMT

{"hostname":"server-f9999df48-rmj6n","time":"11:39:49","version":1}
NAME               DESIRED   CURRENT   READY   AGE
server-f9999df48   3         3         3       5m2s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:39:55 GMT

{"hostname":"server-f9999df48-67zw4","time":"11:39:55","version":1}

````

We can see traffic is load balanced between pods.


We can observe that when creating service no `containerPort` was created unlike `kubectl run`
Impact can be seen when using the proxy. See note on [container port](./container-port.md).

## Load new software version: v2 and trigger a new deployment

We will slow down the deployment process by setting `minReadySeconds`.
This forces to wait that readiness is passed for at least 10 seconds before moving on nexrt steps of the rolling strategy.
At this step no readiness is defined so it will always be the case.

````shell script
k patch deployment server -p '{"spec": {"minReadySeconds": 10}}'
````

I will now trigger a new deployment, by doing `$ k explain deployment.spec.strategy`
We can see default maxSurge is 25%, and maxUnavailable is 25%,
With 3 replicas maxSurge and maxUnavailable will be 1.

<!--
p272-compliant
note maxUnavailable is relative to #replicas, so we can have more unavailable pod OK
-->



In a second window do 
````shell script
./status.sh
````

And trigger the deployment

````shell script
k set image deployment server server=server:v2 --record=true
````

Alternatively I could have used:
- edit 
- patch 
- apply
- replace

Output is

````
[vagrant@archlinux ~]$ ./status.sh
NAME               DESIRED   CURRENT   READY   AGE
server-f9999df48   3         3         3       5m59s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:40:52 GMT

{"hostname":"server-f9999df48-67zw4","time":"11:40:52","version":1}
NAME               DESIRED   CURRENT   READY   AGE
server-f9999df48   3         3         3       6m5s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:40:57 GMT

{"hostname":"server-f9999df48-67zw4","time":"11:40:57","version":1}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   1         1         1       4s
server-f9999df48    3         3         3       6m10s
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:02 GMT

{"hostname":"server-6948dc4f7f-9298l","time":"11:41:02","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   1         1         1       9s
server-f9999df48    3         3         3       6m15s
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:07 GMT

{"hostname":"server-f9999df48-rmj6n","time":"11:41:07","version":1}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   2         2         2       14s
server-f9999df48    2         2         2       6m20s
Waiting for deployment "server" rollout to finish: 2 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:13 GMT

{"hostname":"server-f9999df48-rmj6n","time":"11:41:13","version":1}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   2         2         2       20s
server-f9999df48    2         2         2       6m26s
Waiting for deployment "server" rollout to finish: 2 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 68
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:18 GMT

{"hostname":"server-f9999df48-rmj6n","time":"11:41:18","version":1}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   3         3         3       25s
server-f9999df48    1         1         1       6m31s
Waiting for deployment "server" rollout to finish: 1 old replicas are pending termination...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:23 GMT

{"hostname":"server-6948dc4f7f-wjvpc","time":"11:41:23","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   3         3         3       30s
server-f9999df48    1         1         1       6m36s
Waiting for deployment "server" rollout to finish: 1 old replicas are pending termination...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:28 GMT

{"hostname":"server-6948dc4f7f-q6x5d","time":"11:41:28","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   3         3         3       35s
server-f9999df48    0         0         0       6m41s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:34 GMT

{"hostname":"server-6948dc4f7f-q6x5d","time":"11:41:34","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   3         3         3       41s
server-f9999df48    0         0         0       6m47s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:39 GMT

{"hostname":"server-6948dc4f7f-q6x5d","time":"11:41:39","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   3         3         3       46s
server-f9999df48    0         0         0       6m52s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:41:44 GMT

{"hostname":"server-6948dc4f7f-9298l","time":"11:41:44","version":2}
````


We can see rs scale-up/down and that at the beginning of load we start targetting v2 which is ready.
We also see the hiistoy with the revision 2 and the status.


## Loading a buggy version and perform a rollback (rolling back) 

How to undo a roll out?

### Load v3 alias buggy version

We will load v3, which returns a 500 after 12 seconds :).

In a second window do 
````shell script
./status.sh
```

And trigger the deployment

````shell script
k set image deployment server server=server:v3 --record=true
````

Output is 

````shell script
[vagrant@archlinux ~]$ ./status.sh
NAME                DESIRED   CURRENT   READY   AGE
server-6948dc4f7f   3         3         3       2m19s
server-f9999df48    0         0         0       8m25s
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:43:18 GMT

{"hostname":"server-6948dc4f7f-q6x5d","time":"11:43:18","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   1         1         0       2s
server-6948dc4f7f   3         3         3       2m25s
server-f9999df48    0         0         0       8m31s
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:43:23 GMT

{"hostname":"server-6948dc4f7f-wjvpc","time":"11:43:23","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   1         1         1       7s
server-6948dc4f7f   3         3         3       2m30s
server-f9999df48    0         0         0       8m36s
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 96
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:43:28 GMT

{"hostname":"server-5984c4bbf8-pbbz6","time":"11:43:28","uptime":4.829425811767578,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   1         1         1       12s
server-6948dc4f7f   3         3         3       2m35s
server-f9999df48    0         0         0       8m41s
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:43:33 GMT

{"hostname":"server-6948dc4f7f-q6x5d","time":"11:43:33","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   2         2         2       17s
server-6948dc4f7f   2         2         2       2m40s
server-f9999df48    0         0         0       8m46s
Waiting for deployment "server" rollout to finish: 2 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:43:39 GMT

{"hostname":"server-6948dc4f7f-9298l","time":"11:43:39","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   2         2         2       23s
server-6948dc4f7f   2         2         2       2m46s
server-f9999df48    0         0         0       8m52s
Waiting for deployment "server" rollout to finish: 2 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:43:44 GMT

{"hostname":"server-6948dc4f7f-wjvpc","time":"11:43:44","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       28s
server-6948dc4f7f   1         1         1       2m51s
server-f9999df48    0         0         0       8m57s
Waiting for deployment "server" rollout to finish: 1 old replicas are pending termination...
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 97
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:43:49 GMT

{"hostname":"server-5984c4bbf8-7pr9b","time":"11:43:49","uptime":14.168801069259644,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       33s
server-6948dc4f7f   1         1         1       2m56s
server-f9999df48    0         0         0       9m2s
Waiting for deployment "server" rollout to finish: 1 old replicas are pending termination...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 97
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:43:54 GMT

{"hostname":"server-5984c4bbf8-7clcd","time":"11:43:54","uptime":7.8447840213775635,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       39s
server-6948dc4f7f   0         0         0       3m2s
server-f9999df48    0         0         0       9m8s
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 96
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:44:00 GMT

{"hostname":"server-5984c4bbf8-7pr9b","time":"11:44:00","uptime":24.93539309501648,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       44s
server-6948dc4f7f   0         0         0       3m7s
server-f9999df48    0         0         0       9m13s
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 97
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:44:05 GMT

{"hostname":"server-5984c4bbf8-7pr9b","time":"11:44:05","uptime":30.202624559402466,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       49s
server-6948dc4f7f   0         0         0       3m12s
server-f9999df48    0         0         0       9m18s
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 97
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:44:11 GMT

{"hostname":"server-5984c4bbf8-7clcd","time":"11:44:11","uptime":23.913522481918335,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       55s
server-6948dc4f7f   0         0         0       3m18s
server-f9999df48    0         0         0       9m24s
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 96
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:44:16 GMT

{"hostname":"server-5984c4bbf8-pbbz6","time":"11:44:16","uptime":52.56724572181702,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       60s
server-6948dc4f7f   0         0         0       3m23s
server-f9999df48    0         0         0       9m29s
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 97
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:44:21 GMT

{"hostname":"server-5984c4bbf8-7pr9b","time":"11:44:21","uptime":46.055004835128784,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       65s
server-6948dc4f7f   0         0         0       3m28s
server-f9999df48    0         0         0       9m34s
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 96
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:44:26 GMT

{"hostname":"server-5984c4bbf8-7pr9b","time":"11:44:26","uptime":51.33511924743652,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       70s
server-6948dc4f7f   0         0         0       3m33s
server-f9999df48    0         0         0       9m39s
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 95
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:44:32 GMT

{"hostname":"server-5984c4bbf8-7clcd","time":"11:44:32","uptime":45.0423104763031,"version":3}NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       76s
server-6948dc4f7f   0         0         0       3m39s
server-f9999df48    0         0         0       9m45s
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 97
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:44:37 GMT

{"hostname":"server-5984c4bbf8-7pr9b","time":"11:44:37","uptime":61.884807109832764,"version":3}

````

During the load version 2 and 3, accepts the traffic.
version 3 is working (first 12 seconds), after 12 seconds version 2 does not exist.
And we have only buggy version 3 which returns a 500.

As we do not want to return a 500, we will rollout v3 and come back to v2.

````shell script
[vagrant@archlinux ~]$ k rollout undo deployment server
deployment.apps/server rolled back
````

````shell script
[vagrant@archlinux ~]$ ./status.sh
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       5m21s
server-6948dc4f7f   0         0         0       7m44s
server-f9999df48    0         0         0       13m
deployment "server" successfully rolled out
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 97
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:48:42 GMT

{"hostname":"server-5984c4bbf8-7pr9b","time":"11:48:42","uptime":307.17922949790955,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       5m26s
server-6948dc4f7f   1         1         1       7m49s
server-f9999df48    0         0         0       13m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 97
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:48:47 GMT

{"hostname":"server-5984c4bbf8-7pr9b","time":"11:48:47","uptime":312.43753361701965,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   3         3         3       5m32s
server-6948dc4f7f   1         1         1       7m55s
server-f9999df48    0         0         0       14m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:48:53 GMT

{"hostname":"server-6948dc4f7f-lq2sv","time":"11:48:53","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   2         2         2       5m37s
server-6948dc4f7f   2         2         2       8m
server-f9999df48    0         0         0       14m
Waiting for deployment "server" rollout to finish: 2 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:48:58 GMT

{"hostname":"server-6948dc4f7f-49phq","time":"11:48:58","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   2         2         2       5m43s
server-6948dc4f7f   2         2         2       8m6s
server-f9999df48    0         0         0       14m
Waiting for deployment "server" rollout to finish: 2 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:49:04 GMT

{"hostname":"server-6948dc4f7f-lq2sv","time":"11:49:04","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   1         1         1       5m48s
server-6948dc4f7f   3         3         3       8m11s
server-f9999df48    0         0         0       14m
Waiting for deployment "server" rollout to finish: 1 old replicas are pending termination...
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 96
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:49:09 GMT

{"hostname":"server-5984c4bbf8-pbbz6","time":"11:49:09","uptime":345.6784553527832,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   1         1         1       5m53s
server-6948dc4f7f   3         3         3       8m16s
server-f9999df48    0         0         0       14m
Waiting for deployment "server" rollout to finish: 1 old replicas are pending termination...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:49:14 GMT

{"hostname":"server-6948dc4f7f-lq2sv","time":"11:49:14","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       5m58s
server-6948dc4f7f   3         3         3       8m21s
server-f9999df48    0         0         0       14m
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:49:20 GMT
````

We can see we went back to the old rc.

## Pausing the rollout process

We are in v2, we will load v4 but pause the deployment, to check everything is good.
This will perform a canary release.

History is:

````shell script
[vagrant@archlinux ~]$ k rollout history deployment server
deployment.apps/server
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=- --record=true
3         kubectl set image deployment server server=server:v3 --record=true
4         kubectl set image deployment server server=server:v2 --record=true
````

Note revision 4 is revision (rollbacked).

As usual launch (clear, for copy/paste) and `./status.sh` in a second windows and perform the v4 load with a pause.

````shell script
k set image deployment server server=server:v4 --record=true
k rollout pause deployment server
````

Output is 

````shell script
[vagrant@archlinux ~]$ ./status.sh
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       15m
server-6948dc4f7f   3         3         3       18m
server-f9999df48    0         0         0       24m
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:59:14 GMT

{"hostname":"server-6948dc4f7f-49phq","time":"11:59:14","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       15m
server-65498f85c    1         1         1       2s
server-6948dc4f7f   3         3         3       18m
server-f9999df48    0         0         0       24m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:59:19 GMT

{"hostname":"server-6948dc4f7f-49phq","time":"11:59:19","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       16m
server-65498f85c    1         1         1       7s
server-6948dc4f7f   3         3         3       18m
server-f9999df48    0         0         0       24m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 95
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:59:25 GMT

{"hostname":"server-65498f85c-4m6hw","time":"11:59:25","uptime":5.920163869857788,"version":4}NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       16m
server-65498f85c    1         1         1       13s
server-6948dc4f7f   3         3         3       18m
server-f9999df48    0         0         0       24m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:59:30 GMT

{"hostname":"server-6948dc4f7f-24l7m","time":"11:59:30","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       16m
server-65498f85c    1         1         1       18s
server-6948dc4f7f   3         3         3       18m
server-f9999df48    0         0         0       24m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 11:59:35 GMT

````

So we have v2 and v4, and v2 remains as deployment is paused.

We can resume the deployment.

````shell script
k rollout resume deployment server 
````

And depployment will be finished

````shell script
"hostname":"server-65498f85c-4m6hw","time":"12:03:46","uptime":266.9630117416382,"version":4}NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       20m
server-65498f85c    3         3         3       4m34s
server-6948dc4f7f   1         1         1       22m
server-f9999df48    0         0         0       28m
Waiting for deployment "server" rollout to finish: 1 old replicas are pending termination...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 12:03:51 GMT

{"hostname":"server-6948dc4f7f-lq2sv","time":"12:03:51","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       20m
server-65498f85c    3         3         3       4m39s
server-6948dc4f7f   1         1         1       22m
server-f9999df48    0         0         0       29m
Waiting for deployment "server" rollout to finish: 1 old replicas are pending termination...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 96
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 12:03:56 GMT

{"hostname":"server-65498f85c-qvjmp","time":"12:03:56","uptime":18.069225549697876,"version":4}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       20m
server-65498f85c    3         3         3       4m44s
server-6948dc4f7f   0         0         0       23m
server-f9999df48    0         0         0       29m
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 96
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 12:04:01 GMT

{"hostname":"server-65498f85c-8gjpc","time":"12:04:01","uptime":11.435797929763794,"version":4}
````

Canar releases could have also been achieved with 2 deployment and one service (again labels!).
Pause can be used to batch changes

## Prevent load of bad version 

In this section  [Load v3 alias buggy version](#Load-v3-alias-buggy-version).
We loaded a version with a defect, as after 12 seconds this versions start returning a 500.
As all instance of v2 had been replaced by v3, application returned a 500.

Is it possible to prevent this?

From the doc

````shell script
[vagrant@archlinux ~]$ k explain deployment.spec.minReadySeconds
KIND:     Deployment
VERSION:  apps/v1

FIELD:    minReadySeconds <integer>

DESCRIPTION:
     Minimum number of seconds for which a newly created pod should be ready
     without any of its container crashing, for it to be considered available.
     Defaults to 0 (pod will be considered available as soon as it is ready)
````

Add adding a readiness probes.
So that if the readiness probes is failing after `deployment.spec.minReadySeconds`, the deployment will be blocked.

We had actually `minReadySeconds` but no readiness was defined, as such it was as if the v3 was working properly.

To come back to the initial state, I will rollback to v2.


````shell script
[vagrant@archlinux ~]$ k rollout history deployment server
deployment.apps/server
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=- --record=true
3         kubectl set image deployment server server=server:v3 --record=true
4         kubectl set image deployment server server=server:v2 --record=true
5         kubectl set image deployment server server=server:v4 --record=true

[vagrant@archlinux ~]$ k rollout undo deployment server --to-revision=4
deployment.apps/server rolled back
[vagrant@archlinux ~]$ k rollout history deployment server
deployment.apps/server
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=- --record=true
3         kubectl set image deployment server server=server:v3 --record=true
5         kubectl set image deployment server server=server:v4 --record=true
6         kubectl set image deployment server server=server:v2 --record=true
````

I will now modify the deployment and start `status.sh` before.

````shell script
cat << EOF | k apply -f - --record
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: server
  name: server
spec:
  replicas: 3 ## if not set it will not change !
  minReadySeconds: 20 # It is superior to 12, which is the beginning of v3 failure
  selector:
    matchLabels:
      app: server
  strategy: {} # Keep the default
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: server
    spec:
      containers:
      - image: server:v3 ## This is the buggy version
        imagePullPolicy: Never ## 
        name: server
        readinessProbe:
          periodSeconds: 1
          httpGet:
            path: /api/v1/time
            port: 8080
        resources: {}
status: {}
EOF
````

Output is 


````shell script
[vagrant@archlinux ~]$ ./status.sh

NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       48m
server-65498f85c    0         0         0       32m
server-6948dc4f7f   3         3         3       50m
server-f9999df48    0         0         0       56m
deployment "server" successfully rolled out
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 12:31:33 GMT

{"hostname":"server-6948dc4f7f-kbn9g","time":"12:31:33","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       48m
server-59b5d8488    1         1         0       1s
server-65498f85c    0         0         0       32m
server-6948dc4f7f   3         3         3       50m
server-f9999df48    0         0         0       56m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 12:31:38 GMT

{"hostname":"server-6948dc4f7f-kbn9g","time":"12:31:38","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       48m
server-59b5d8488    1         1         1       6s
server-65498f85c    0         0         0       32m
server-6948dc4f7f   3         3         3       50m
server-f9999df48    0         0         0       56m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 12:31:44 GMT

{"hostname":"server-6948dc4f7f-9x5xk","time":"12:31:44","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       48m
server-59b5d8488    1         1         1       12s
server-65498f85c    0         0         0       32m
server-6948dc4f7f   3         3         3       50m
server-f9999df48    0         0         0       56m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 12:31:49 GMT

{"hostname":"server-6948dc4f7f-9x5xk","time":"12:31:49","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       48m
server-59b5d8488    1         1         0       17s
server-65498f85c    0         0         0       32m
server-6948dc4f7f   3         3         3       50m
server-f9999df48    0         0         0       57m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 69
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 12:31:54 GMT
````

We can see deployment does not progress and it is more visible here:

````shell script
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                      READY   STATUS    RESTARTS   AGE
server-59b5d8488-hq5sc    0/1     Running   0          4m19s
server-6948dc4f7f-9x5xk   1/1     Running   0          13m
server-6948dc4f7f-kbn9g   1/1     Running   0          14m
server-6948dc4f7f-q7tpd   1/1     Running   0          13m
[12:35] ~
➤ k get rs                                                                                                                                                                    vagrant@archlinuxNAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       52m
server-59b5d8488    1         1         0       4m24s
server-65498f85c    0         0         0       36m
server-6948dc4f7f   3         3         3       55m
server-f9999df48    0         0         0       61m
````

Have a particular look at: `server-59b5d8488`.

And we do not deploy badly version and even not routing any traffic to it as readiness failed.

````shell script
[12:38] ~
➤ k describe pod server-59b5d8488-hq5sc | rg -A 5 Warning                                                                                                                     vagrant@archlinux
  Warning  Unhealthy  2m (x289 over 6m48s)  kubelet, archlinux  Readiness probe failed: HTTP probe failed with statuscode: 500
````

As the rollout will not continue we can rollback it

````shell script
k rollout undo deployment server
````

But we can also wait for (default deadline is set unlike v1beta1)

````shell script
➤ k explain deployment.spec.progressDeadlineSeconds                                                                                                                           vagrant@archlinuxKIND:     Deployment
VERSION:  apps/v1

FIELD:    progressDeadlineSeconds <integer>

DESCRIPTION:
     The maximum time in seconds for a deployment to make progress before it is
     considered to be failed. The deployment controller will continue to process
     failed deployments and a condition with a ProgressDeadlineExceeded reason
     will be surfaced in the deployment status. Note that progress will not be
     estimated during the time a deployment is paused. Defaults to 600s.
````

So status will output:

````shell script
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       60m
server-59b5d8488    1         1         0       11m
server-65498f85c    0         0         0       44m
server-6948dc4f7f   3         3         3       62m
server-f9999df48    0         0         0       68m
error: deployment "server" exceeded its progress deadline
````

Where deployment will be failed 

````shell script
➤ k describe deployment                                                                                                                                                       vagrant@archlinuxName:                   server
[...]
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    False   ProgressDeadlineExceeded
OldReplicaSets:  server-6948dc4f7f (3/3 replicas created)
NewReplicaSet:   server-59b5d8488 (1/1 replicas created)
Events:
  Type    Reason             Age                 From                   Message
  ----    ------             ----                ----                   -------
  Normal  ScalingReplicaSet  41m (x2 over 61m)   deployment-controller  Scaled down replica set server-6948dc4f7f to 2
  Normal  ScalingReplicaSet  41m                 deployment-controller  Scaled down replica set server-6948dc4f7f to 1
  Normal  ScalingReplicaSet  41m (x11 over 61m)  deployment-controller  (combined from similar events): Scaled down replica set server-6948dc4f7f to 0
  Normal  ScalingReplicaSet  23m (x3 over 64m)   deployment-controller  Scaled up replica set server-6948dc4f7f to 1
  Normal  ScalingReplicaSet  23m (x3 over 64m)   deployment-controller  Scaled up replica set server-6948dc4f7f to 2
  Normal  ScalingReplicaSet  23m                 deployment-controller  Scaled down replica set server-65498f85c to 2
  Normal  ScalingReplicaSet  23m (x3 over 63m)   deployment-controller  Scaled up replica set server-6948dc4f7f to 3
  Normal  ScalingReplicaSet  23m                 deployment-controller  Scaled down replica set server-65498f85c to 1
  Normal  ScalingReplicaSet  22m                 deployment-controller  Scaled down replica set server-65498f85c to 0
  Normal  ScalingReplicaSet  13m                 deployment-controller  Scaled up replica set server-59b5d8488 to 1
[12:45] ~
➤                                                                                                                                                                             vagrant@archlinux[12:45] ~
➤ k get rs                                                                                                                                                                    vagrant@archlinuxNAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       62m
server-59b5d8488    1         1         0       14m
server-65498f85c    0         0         0       46m
server-6948dc4f7f   3         3         3       64m
server-f9999df48    0         0         0       70m
[12:45] ~
➤ k rollout history deployment server                                                                                                                                         vagrant@archlinuxdeployment.apps/server
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=- --record=true
3         kubectl set image deployment server server=server:v3 --record=true
5         kubectl set image deployment server server=server:v4 --record=true
6         kubectl set image deployment server server=server:v2 --record=true
7         kubectl apply --filename=- --record=true

➤ k rollout status deployment server                                                                                                                                          vagrant@archlinux
error: deployment "server" exceeded its progress deadline
````

And it is not aborted automatically (not yet done), I have to do it

````shell script
k rollout undo deployment server
````

So that 


````shell script

[12:50] ~
➤ k describe deployment                                                                                                                                                       vagrant@archlinuxName:                   server
[...]
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   server-6948dc4f7f (3/3 replicas created)
Events:
  Type    Reason             Age                 From                   Message
  ----    ------             ----                ----                   -------
  Normal  ScalingReplicaSet  46m (x2 over 66m)   deployment-controller  Scaled down replica set server-6948dc4f7f to 2
  Normal  ScalingReplicaSet  46m                 deployment-controller  Scaled down replica set server-6948dc4f7f to 1
  Normal  ScalingReplicaSet  46m (x11 over 66m)  deployment-controller  (combined from similar events): Scaled down replica set server-6948dc4f7f to 0
  Normal  ScalingReplicaSet  28m (x3 over 69m)   deployment-controller  Scaled up replica set server-6948dc4f7f to 1
  Normal  ScalingReplicaSet  28m (x3 over 68m)   deployment-controller  Scaled up replica set server-6948dc4f7f to 2
  Normal  ScalingReplicaSet  28m                 deployment-controller  Scaled down replica set server-65498f85c to 2
  Normal  ScalingReplicaSet  27m (x3 over 68m)   deployment-controller  Scaled up replica set server-6948dc4f7f to 3
  Normal  ScalingReplicaSet  27m                 deployment-controller  Scaled down replica set server-65498f85c to 1
  Normal  ScalingReplicaSet  27m                 deployment-controller  Scaled down replica set server-65498f85c to 0
  Normal  ScalingReplicaSet  18m                 deployment-controller  Scaled up replica set server-59b5d8488 to 1
  Normal  ScalingReplicaSet  51s                 deployment-controller  Scaled down replica set server-59b5d8488 to 0
[12:50] ~
➤ k get rs                                                                                                                                                                    vagrant@archlinuxNAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       67m
server-59b5d8488    0         0         0       18m
server-65498f85c    0         0         0       51m
server-6948dc4f7f   3         3         3       69m
server-f9999df48    0         0         0       75m
[12:50] ~
➤ k rollout history deployment server                                                                                                                                         vagrant@archlinuxdeployment.apps/server
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=- --record=true
3         kubectl set image deployment server server=server:v3 --record=true
5         kubectl set image deployment server server=server:v4 --record=true
7         kubectl apply --filename=- --record=true
8         kubectl set image deployment server server=server:v2 --record=true

[12:50] ~
➤ k rollout status deployment server                                                                                                                                          vagrant@archlinuxdeployment "server" successfully rolled out
                                                                                                                                                                      vagrant@archlinux
````



<!--
SO OK THIS IS CRISTAL CLEAR !! STOP
Note on dash in same Luska chapter. had seen it in [here doc](../../Master-Kubectl/here-doc.md).
-->

So we are in v2, I am wondering if traffic could still be directed to v2 pods when readiness is passing.
I will for this scale down to 1 and reapply the deployment, and status (with the sleep removed) in a different window.


````shell script
k scale deployment server --replicas=1

cat << EOF | k apply -f - --record
[...]
````

And the answer is yes where last v3 is 



````shell script

{"hostname":"server-6948dc4f7f-f9wnm","time":"13:12:37","version":2}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       89m
server-59b5d8488    1         1         1       41m
server-65498f85c    0         0         0       73m
server-6948dc4f7f   3         3         3       91m
server-f9999df48    0         0         0       97m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 95
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 13:12:37 GMT

# Last occurence of version 3 reached
{"hostname":"server-59b5d8488-zz856","time":"13:12:37","uptime":9.669060468673706,"version":3}
NAME                DESIRED   CURRENT   READY   AGE
server-5984c4bbf8   0         0         0       89m
server-59b5d8488    1         1         1       41m
server-65498f85c    0         0         0       73m
server-6948dc4f7f   3         3         3       91m
server-f9999df48    0         0         0       97m
Waiting for deployment "server" rollout to finish: 1 out of 3 new replicas have been updated...
HTTP/1.0 500 INTERNAL SERVER ERROR
Content-Type: application/json
Content-Length: 96
Server: Werkzeug/1.0.1 Python/3.8.3
Date: Tue, 26 May 2020 13:12:41 GMT

{"hostname":"server-59b5d8488-zz856","time":"13:12:41","uptime":13.432401895523071,"version":3}
````

We have a 500, at 13 seconds from v3.
This the last time we target v3 because  after resdiness failed.
This the last time we target v3 because  after resdiness failed.
Here it was targetted because we check it every second OK

<!--
Note: I add an intermediate version as first try failed
At the bginning I wanted to make a command in deployment and run a command in readiness
but better with docker OK STOP
-->

See note on [container port](./container-port.md).

<!--
ONLY REMAINING HERE
- ALL IS OK HERE
- Lien note ckad exo juge OK
- Had copied last version of sample APP OK
- Note sur le proxy OK
-->
