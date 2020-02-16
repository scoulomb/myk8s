## Prereq

- Start up k8s VM with vagrant
- ./restart.sh to restart kube
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

## Edit deployment


```shell script
vagrant@k8sMaster:~/apptest$ k rollout history deployment test-registry
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
1         <none>

```
we will edit deployment to run version 2

```shell script
k edit deployment test-registry 
# -> change image to v2, not we use lastest default tag which is actually not the last image, which is v2! 
```

This triggers a redeployment:

```
vagrant@k8sMaster:~/apptest$ k get pods
NAME                                    READY   STATUS             RESTARTS   AGE
[..]
test-registry-6bdd4b5bdb-pwz4r          1/1     Terminating        0          13m
test-registry-6f544c8468-w8qnw          1/1     Running            0          26s
```

then do 

```shell script
export POD_NAME_1=$(k get pods -o wide | grep "test-registry-" |  sed -n 1p | awk '{ print $1 }')
echo $POD_NAME_1
k logs -f $POD_NAME_1
```

Output is

```shell script
> hostV2: test-registry-6f544c8468-w8qnw
> dateV2: 2020-02-16 15:16:05

> hostV2: test-registry-6f544c8468-w8qnw
> dateV2: 2020-02-16 15:16:10

> hostV2: test-registry-6f544c8468-w8qnw
> dateV2: 2020-02-16 15:16:15
```

## Rollback to previous version

```shell script
vagrant@k8sMaster:~/apptest$ k rollout history deployment test-registry
deployment.apps/test-registry
REVISION  CHANGE-CAUSE
1         <none>
2         <none>


vagrant@k8sMaster:~/apptest$ k rollout undo --dry-run=true deployment test-registry --to-revision 1
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
vagrant@k8sMaster:~/apptest$ k rollout undo --dry-run=true deployment test-registry --to-revision
2
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

```

We can see move from v1 to v2. Applying the change

```shell script
vagrant@k8sMaster:~/apptest$ k rollout undo --dry-run=false deployment test-registry --to-revision 1
deployment.apps/test-registry rolled back
vagrant@k8sMaster:~/apptest$ k get pods
[..]
test-registry-6bdd4b5bdb-8dvdh          1/1     Running            0          4s
test-registry-6f544c8468-w8qnw          1/1     Terminating        0          7m17s

vagrant@k8sMaster:~/apptest$ k logs -f test-registry-6bdd4b5bdb-8dvdh
> host: test-registry-6bdd4b5bdb-8dvdh
> date: 2020-02-16 15:21:18

> host: test-registry-6bdd4b5bdb-8dvdh
> date: 2020-02-16 15:21:23

```

We came back to version 1.
