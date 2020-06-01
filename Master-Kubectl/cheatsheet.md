# Cheatsheet

## Environment preparation 


Details can be found [here](https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/article.md)


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


## Object creation 

For details (command...) see [here](https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md).
<!--
clear
-->

### Pod

````commandline
k run alpine --image alpine --restart=Never --dry-run=client -o yaml -- /bin/sleep 10
````


### Job

````shell script
k create job alpine-job --image alpine --dry-run=client -o yaml -- /bin/sleep 10
```` 

### Cronjob 

````shell script
k create cronjob alpine-cronjob --image alpine  --schedule="* * * * *" --dry-run=client -o yaml -- /bin/sleep 30 
````

### Replicaset

````shell script
echo '
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: alpine-rs
  labels:
    # Not used in pod matching, this is for the rs
    applabel: alpine-rs
spec:
  # modify replicas according to your case
  replicas: 3
  selector:
    # https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/#pod-template
    matchLabels:
      app: rssample
  template:
    metadata:
      labels:
        app: rssample
    spec:
      containers:
      - name: alpine
        command:
        - /bin/sleep
        - "3600"
        image: alpine' > alpine-rs.yaml
k create -f alpine-rs.yaml # --dry-run=client
````

### Deployment 

````shell script
k create deployment alpine-deployment --image=alpine --dry-run=client -o yaml 
````

## Run instruction inside a container

Details [here](https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/4-Run-instructions-into-a-container.md)


### Inject instruction in run 

Pod will be temporary depending if we use `--rm` option or not.

#### Using interactive shell

```bash
k run busybox --image=busybox --restart=Never -it --rm -- sh
wget -O- POD_IP:80 | head -n 8 # do not try with pod name, will not work
# try hitting all IPs to confirm that hostname is different
exit
```

#### But we could inject command directly 

````shell script
k run mypod --rm -it --image=busybox --restart=Never -- wget -O- 172.17.0.5:80
````

We can also use the IP var with 2 ways shell subsitution or forward enviornment var

````shell script
k run mypod --rm -it --image=busybox --restart=Never -- wget -O- "$IP":80
k run mypod --rm -it --image=busybox --restart=Never --env="IP=$IP" -- wget -O- $IP:80
````

#### Note on temporary pod are not 

Note `i` is always mandatory here but  t become optional when injecting command directly.
 rm` if we want pod deletion. If rm is removed container will not be deleted automatically


#### We can use '/bin/sh -c'    

We can also do: 

````shell script
k run toto --rm -it --image=busybox --restart=Never --env="IP=$IP" -- /bin/sh -c  'wget -O- $IP:80 | head -n 5'
````

#### We can also remove rm and it, and use logs

`k run busybox --image=busybox --restart=Never  --env="IP=$IP" --command -- /bin/sh -c 'wget -O- $IP:80 | head -n 5' ; sleep 10; k logs busybox; k delete po busybox`

### Injection - instructions in exec


#### Create pod 

````shell script
k run busybox --image=busybox --restart=Never --env="IP=$IP" -- sleep 3600
````
First line of this technique is a particular case of injecting instruction in run 

#### Executing cmd

##### Method A

````shell script
k exec -it busybox -- sh # (1)
wget -O- $IP:80 # (2)
````


#### Method B

=> xor (3) = (1) + (2) merged, inject command directly

````shell script
k exec -it busybox -- wget -O- $IP:80 # (3)
````

Here `it` is not mandatory.



## Generate manifest

Details [here](https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/4-Run-instructions-into-a-container.md#generate-manifest)


We can use it with `k apply -f`
- by outputting to a file 

```shell script
k run busybox --image=busybox --restart=Never --command --dry-run -o yaml -- /bin/sh -c 'wget -O- 172.17.0.4:8080' > o.yaml
k apply -f o.yaml
```
- Or one line

```
k run busybox --image=busybox --restart=Never --command --dry-run -o yaml -- /bin/sh -c 'wget -O- 172.17.0.4:8080' | k apply -f -
```

We can also use create instead of apply,
Note the difference between the 2 [here](https://stackoverflow.com/questions/47369351/kubectl-apply-vs-kubectl-create)


## Force deletion

Details can be found [here](https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/4-Run-instructions-into-a-container.md#force-deletion) 

`k delete po --all --force --grace-period=0`

## Multicontainer

Details can be found [here](https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/4-Run-instructions-into-a-container.md#force-deletion)

Select container with `-c` in `k exec`.
if `k run`, simplest is to generate yaml and edit it.

## Deployment

Details can be found [here](https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/article.md)

### Deploy first version
````shell script
k create deployment server --image=server:v1 --dry-run -o yaml
`````

We will use imagePullPolicy to Never to use locally built image


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


### Load new software version: v2 and trigger a new deployment

````shell script
k set image deployment server server=server:v2 --record=true
````

Alternatively I could have used:
- edit 
- patch 
- apply
- replace


### Loading a buggy version and perform a rollback (rolling back) 

How to undo a roll out?


````shell script
k set image deployment server server=server:v3 --record=true
````

````shell script
k rollout undo deployment server
````

### Pausing the rollout process


````shell script
k set image deployment server server=server:v4 --record=true
k rollout pause deployment server
````

We can resume the deployment.

````shell script
k rollout resume deployment server 
````

### View history

````shell script
k rollout history deployment server
````

## Service and Container port 

Details can be found [here](https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/container-port.md)

###  Create pod with service and container port 


````buildoutcfg
 k run nginx --image=nginx --restart=Never --port=80 --expose --dry-run -o yaml
````

### Create deployment with service and container port 

````shell
k delete deployment --all
k create deployment nginx-deployment --image=nginx:1.14.2 
k scale deployment nginx-deployment --replicas=3 --record 
k patch deployment nginx-deployment --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports", "value": [ { "containerPort": 80 } ] }]' --record
k expose deployment nginx-deployment --port=80
````

## Port forwarding 

Details can be found [here](https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/container-port.md#is-it-an-issue-to-not-have-the-containerport)


````shell script
➤ sudo pacman -S socat
````

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


## Using kubectl proxy

Details can be found [here](https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/container-port.md#is-it-an-issue-to-not-have-the-containerport)

````shell script
k proxy --port=8080 # Launch with sudo on minikube oterwise 401 error 
````

Then in another window

````shell script
curl http://localhost:8080/api/
````
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

## Configmap and secrets 

Several ways 

````shell script
k create cm -h
k create secrets -h
````