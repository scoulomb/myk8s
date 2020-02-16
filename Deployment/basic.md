## Prereq

- Start up k8s VM with [Vagrant](../tooling/SimpleSetup)
- [restary script](../tooling/SimpleSetup/restart.sh) to restart kube
- [registry deployment](../tooling/deploy-local-registry.sh)
- [test local registry](../tooling/test-local-registry.sh)

## Make a v2

```
cd ~
mkdir apptest
cd apptest

echo '
#!/usr/bin/python
## Import the necessary modules
import time
import socket

## Use an ongoing while loop to generate output
while True :
  host = socket.gethostname()
  date = time.strftime("%Y-%m-%d %H:%M:%S")
  print(f"> hostV2: {host}\n> dateV2: {date}\n")
  time.sleep(5)
' > testregistry.py

echo '
FROM python:3
ADD testregistry.py /
# https://stackoverflow.com/questions/29663459/python-app-does-not-print-anything-when-running-detached-in-docker
CMD ["python", "-u", "./testregistry.py"]
' > Dockerfile

sudo docker build -t testregistry .
registry_svc_ip=$(kubectl get svc | grep registry | awk '{ print $3 }')
echo $registry_svc_ip
sudo docker tag testregistry $registry_svc_ip:5000/testregistry:v2
sudo docker push $registry_svc_ip:5000/testregistry:v2
sudo docker run $registry_svc_ip:5000/testregistry:v2'

```

## Check v1 status


```shell script
vagrant@k8sMaster:~$ k rollout history deployment test-registry
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
1         <none>
```

We will scale to 3 replicas:

````shell script
k scale --replicas=3 deployment/test-registry
````
As consequence we have 3 test-registry with v1 (latest tag but not v2)
````shell script
vagrant@k8sMaster:~$ k get pods | grep test-registry
test-registry-6bdd4b5bdb-55bdz          1/1     Running            0          2m6s
test-registry-6bdd4b5bdb-5qdjb          1/1     Running            0          15s
test-registry-6bdd4b5bdb-64thk          1/1     Running            0          15s
````

Note after scaling up, we still have a single revision:
As we did not touch the pod template.

````shell script
vagrant@k8sMaster:~$ k rollout history deployment test-registry
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
1         <none>
````

We can check the replica set:

````shell script
vagrant@k8sMaster:~$ k get replicasets | grep test-registry
test-registry-6bdd4b5bdb          3         3         3       6m19s
````

## Edit deployment to run v2

This function gives the status

````
status() {
echo '-- Deployment'
k get deployment | grep test-registry
echo '-- Replicasets'
k get replicasets | grep test-registry
echo '-- Pods'
k get pods | grep test-registry
echo '-- History'
k rollout history deployment test-registry
}
````

So before editing deployment

````shell script
vagrant@k8sMaster:~$ status
-- Deployment
test-registry          3/3     3            3           15m
-- Replicasets
test-registry-6bdd4b5bdb          3         3         3       15m
-- Pods
test-registry-6bdd4b5bdb-55bdz          1/1     Running            0          15m
test-registry-6bdd4b5bdb-5qdjb          1/1     Running            0          13m
test-registry-6bdd4b5bdb-64thk          1/1     Running            0          13m
-- History
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
1         <none>
````

We will edit deployment to run version 2

````shell script
k edit deployment test-registry 
````

Change image to v2, not we use latest default tag which is actually not the last image, which is v2! 
````shell script
spec:
  containers:
    - image: 10.106.76.46:5000/testregistry:v2
````



This triggers a redeployment:

````shell script
vagrant@k8sMaster:~$ k edit deployment test-registry
deployment.apps/test-registry edited
vagrant@k8sMaster:~$ status
-- Deployment
test-registry          3/3     2            3           17m
-- Replicasets
test-registry-6bdd4b5bdb          2         2         2       17m
test-registry-6f544c8468          2         2         1       4s
-- Pods
test-registry-6bdd4b5bdb-55bdz          1/1     Running             0          17m
test-registry-6bdd4b5bdb-5qdjb          1/1     Running             0          15m
test-registry-6bdd4b5bdb-64thk          1/1     Terminating         0          15m
test-registry-6f544c8468-67rsl          0/1     ContainerCreating   0          2s
test-registry-6f544c8468-84n7w          1/1     Running             0          4s
-- History
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

vagrant@k8sMaster:~$ status
-- Deployment
test-registry          3/3     3            3           17m
-- Replicasets
test-registry-6bdd4b5bdb          0         0         0       17m
test-registry-6f544c8468          3         3         3       20s
-- Pods
test-registry-6bdd4b5bdb-55bdz          1/1     Terminating        0          17m
test-registry-6bdd4b5bdb-5qdjb          1/1     Terminating        0          15m
test-registry-6bdd4b5bdb-64thk          1/1     Terminating        0          15m
test-registry-6f544c8468-67rsl          1/1     Running            0          18s
test-registry-6f544c8468-84n7w          1/1     Running            0          20s
test-registry-6f544c8468-9z2j5          1/1     Running            0          15s
-- History
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
````

We can see pods redeploy with version v2 and the with v1 (latest tag are terminated)

then do 

```shell script
export POD_NAME_1=$(k get pods -o wide | grep "test-registry-" |  sed -n 1p | awk '{ print $1 }')
echo $POD_NAME_1
k logs -f $POD_NAME_1
```

Output is

```shell script
> hostV2: test-registry-6f544c8468-67rsl
> dateV2: 2020-02-16 18:27:48

> hostV2: test-registry-6f544c8468-67rsl
> dateV2: 2020-02-16 18:27:53
```

## Rollback to previous version

````shell script
vagrant@k8sMaster:~$ k rollout undo --dry-run=true deployment test-registry --to-revision 1
deployment.apps/test-registry Pod Template:
  Labels:       app=test-registry
        pod-template-hash=6bdd4b5bdb
  Containers:
   testregistry:
    Image:      10.106.76.46:5000/testregistry
    Port:       <none>
    Host Port:  <none>
    Environment:        <none>
    Mounts:     <none>
  Volumes:      <none>
 (dry run)
vagrant@k8sMaster:~$ k rollout undo --dry-run=true deployment test-registry --to-revision 2
deployment.apps/test-registry Pod Template:
  Labels:       app=test-registry
        pod-template-hash=6f544c8468
  Containers:
   testregistry:
    Image:      10.106.76.46:5000/testregistry:v2
    Port:       <none>
    Host Port:  <none>
    Environment:        <none>
    Mounts:     <none>
  Volumes:      <none>
 (dry run)
vagrant@k8sMaster:~$
````

We can see move from v1 to v2. 
Applying the change

````shell script
vagrant@k8sMaster:~$ k rollout undo --dry-run=false deployment test-registry --to-revision 1
deployment.apps/test-registry rolled back
vagrant@k8sMaster:~$ status
-- Deployment
test-registry          3/3     2            3           21m
-- Replicasets
test-registry-6bdd4b5bdb          2         2         1       21m
test-registry-6f544c8468          2         2         2       5m3s
-- Pods
test-registry-6bdd4b5bdb-5sf58          0/1     ContainerCreating   0          2s
test-registry-6bdd4b5bdb-hblcg          1/1     Running             0          5s
test-registry-6f544c8468-67rsl          1/1     Running             0          5m2s
test-registry-6f544c8468-84n7w          1/1     Running             0          5m4s
test-registry-6f544c8468-9z2j5          1/1     Terminating         0          4m59s
-- History
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
2         <none>
3         <none>

vagrant@k8sMaster:~$ status
-- Deployment
test-registry          3/3     3            3           22m
-- Replicasets
test-registry-6bdd4b5bdb          3         3         3       22m
test-registry-6f544c8468          0         0         0       5m12s
-- Pods
test-registry-6bdd4b5bdb-5sf58          1/1     Running            0          11s
test-registry-6bdd4b5bdb-h8l82          1/1     Running            0          9s
test-registry-6bdd4b5bdb-hblcg          1/1     Running            0          14s
test-registry-6f544c8468-67rsl          1/1     Terminating        0          5m11s
test-registry-6f544c8468-84n7w          1/1     Terminating        0          5m13s
test-registry-6f544c8468-9z2j5          1/1     Terminating        0          5m8s
-- History
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
2         <none>
3         <none>

vagrant@k8sMaster:~$

````

We can notice:
- it adds a supplementary version in history
- previous replication controller is reused: test-registry-6bdd4b5bdb   
- It balance the number of pods based on Max surge and unavailable 
- Pod name is `deploymentname-<replica-set-id>-<pod-id>`
We can check that logs are in v1

```shell script
k logs -f test-registry-6bdd4b5bdb-[TAB]

vagrant@k8sMaster:~/apptest$ k logs -f test-registry-6bdd4b5bdb-[TAB]
> host: test-registry-6bdd4b5bdb-5sf58
> date: 2020-02-16 18:36:47

> host: test-registry-6bdd4b5bdb-5sf58
> date: 2020-02-16 18:36:52

```

We came back to version 1!

## Undo on undo

````shell script
vagrant@k8sMaster:~$ k rollout history deployment test-registry
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
2         <none> # <- v2
3         <none> # <- v1
````

So rollout to rev1 is equal to rev3,
I will come back on rev3 (current)

````shell script
vagrant@k8sMaster:~$  k rollout undo --dry-run=false deployment test-registry --to-revision=3
deployment.apps/test-registry skipped rollback (current template already matches revision 3)
vagrant@k8sMaster:~$ status
-- Deployment
test-registry          3/3     3            3           31m
-- Replicasets
test-registry-6bdd4b5bdb          3         3         3       31m
test-registry-6f544c8468          0         0         0       14m
-- Pods
test-registry-6bdd4b5bdb-5sf58          1/1     Running            0          9m30s
test-registry-6bdd4b5bdb-h8l82          1/1     Running            0          9m28s
test-registry-6bdd4b5bdb-hblcg          1/1     Running            0          9m33s
-- History
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
2         <none>
3         <none>
````

Nothings happened

And on revision2, we expect to come back on v2

````shell script
vagrant@k8sMaster:~$  k rollout undo --dry-run=false deployment test-registry --to-revision=2
deployment.apps/test-registry rolled back
vagrant@k8sMaster:~$ status
-- Deployment
test-registry          3/3     1            3           33m
-- Replicasets
test-registry-6bdd4b5bdb          2         2         2       33m
test-registry-6f544c8468          2         1         1       16m
-- Pods
test-registry-6bdd4b5bdb-5sf58          1/1     Running             0          11m
test-registry-6bdd4b5bdb-h8l82          1/1     Terminating         0          11m
test-registry-6bdd4b5bdb-hblcg          1/1     Running             0          11m
test-registry-6f544c8468-grhw8          1/1     Running             0          3s
test-registry-6f544c8468-k78wf          0/1     ContainerCreating   0          1s
-- History
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
3         <none>
4         <none>
````

And

````shell script
k logs -f test-registry-6f544c8468-[tab]
> hostV2: test-registry-6f544c8468-k78wf
> dateV2: 2020-02-16 18:43:40

> hostV2: test-registry-6f544c8468-k78wf
> dateV2: 2020-02-16 18:43:45
````