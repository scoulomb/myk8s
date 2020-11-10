# Run instructions into a container

It is an extension of this [CKAD question](https://github.com/dgkanatsios/CKAD-exercises/blob/master/f.services.md#get-the-pod-ips-create-a-temp-busybox-pod-and-trying-hitting-them-on-port-8080).
Except I will use nginx container exposing port 80 for the target container in prerequisite.

## Prerequisite: Launch a target nginx container

From [container-port note](../Deployment/advanced/container-port.md) and [k run explained](./0-kubectl-run-explained.md).

````shell script
k run nginx --image=nginx --restart=Never --port=80 --expose --dry-run -o yaml
# We will run 
k delete po --all
k run nginx --image=nginx --restart=Never --port=80
````


We can see labels:

````shell script
➤ k get po --show-labels                                      vagrant@archlinux
NAME    READY   STATUS    RESTARTS   AGE   LABELS
nginx   1/1     Running   0          13s   run=nginx
````

We have the `run` label, note when using create we have the `app` label. 
As shown in [part 3](./3-Understand-resource-pod-template.md).

<!--
In CKAD question we had app label because added in the manifest.
--> 


## Get the pod IPs 

Here we do not have a service.

```bash
k get pods -l run=nginx -o wide # 'wide' will show pod IPs
````

or use pod name and get IP using JSON path

````shell script
export IP=(k get pod nginx -o jsonpath='{.status.podIP}')
echo $IP
````

Output is:

````shell script
➤ export IP=(k get pod nginx -o jsonpath='{.status.podIP}')   vagrant@archlinux
  echo $IP
172.17.0.5
````

## Create (a temp or not) busybox pod and trying hitting them on port 80 (8080 in original question)

### Inject instruction in run 

Pod will be temporary depending if we use `--rm` option or not.

#### Using interactive shell

```bash
k run busybox --image=busybox --restart=Never -it --rm -- sh
wget -O- POD_IP:80 | head -n 8 # do not try with pod name, will not work
# try hitting all IPs to confirm that hostname is different
exit
```

Output is:

````shell script
[16:52] ~
➤ k run busybox --image=busybox --restart=Never -it --rm -- sh
If you don't see a command prompt, try pressing enter.
/ # wget -O- 172.17.0.5:80 | head -n 8
Connecting to 172.17.0.5:80 (172.17.0.5:80)
writing to stdout
-                    100% |*******************************|   612  0:0<!DOCTYPE html>
0<html>
:<head>
0<title>Welcome to nginx!</title>
0<style>
 ETA    body {

        width: 35em;
written to stdout
        margin: 0 auto;
/ # exit
pod "busybox" deleted
[16:53] ~
````

Note  `i` stands for stdin and `t` for tty

#### But we could inject command directly 

````shell script
k run mypod --rm -it --image=busybox --restart=Never -- wget -O- 172.17.0.5:80
````

Output is

````shell script
[17:10] ~
➤ k run mypod --rm -it --image=busybox --restart=Never -- wget -O- 172.17.0.5:80
Connecting to 172.17.0.5:80 (172.17.0.5:80)
writing to stdout
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
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
-                    100% |********************************|   612  0:00:00 ETAwritten to stdout
pod "mypod" deleted
[17:10] ~
➤                                                             vagrant@archlinux
````

When using `head` we had some issue on deletion (can be solved with `/bin/sh -c`).

We can also use the IP var with 2 ways shell subsitution or forward enviornment var

````shell script
k run mypod --rm -it --image=busybox --restart=Never -- wget -O- "$IP":80
k run mypod --rm -it --image=busybox --restart=Never --env="IP=$IP" -- wget -O- $IP:80
````

Output is 

````shell script
[17:18] ~
➤ k run mypod --rm -it --image=busybox --restart=Never -- wget -O- "$IP":80

Connecting to 172.17.0.5:80 (172.17.0.5:80)
writing to stdout
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
[...]
</body>
</html>
-                    100% |********************************|   612  0:00:00 ETAwritten to stdout
pod "mypod" deleted
[17:18] ~
➤ k run mypod --rm -it --image=busybox --restart=Never --env="IP=$IP" -- wget -O- $IP:80

Connecting to 172.17.0.5:80 (172.17.0.5:80)
writing to stdout
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
[...]
</body>
</html>
-                    100% |********************************|   612  0:00:00 ETAwritten to stdout
pod "mypod" deleted
[17:18] ~
➤                                                             vagrant@archlinux
````

Update: actually the second case is not working and it is a side effect, of the first case and will prove it:

````shell script
IP="216.58.213.131"
sudo kubectl run mypodtsta --rm -it --image=busybox --restart=Never -- wget -O- "$IP":80 | grep Connecting
sudo kubectl run mypodtstb --rm -it --image=busybox --restart=Never --env="IP=$IP" -- wget -O- $IP:80 | grep Connecting
unset IP
sudo kubectl run mypodtstc --rm -it --image=busybox --restart=Never --env="IP=216.58.213.131" -- wget -O- $IP:80 | grep Connecting
sudo kubectl run mypodtstc2 --rm -it --image=busybox --restart=Never --env="IP=216.58.213.131" -- echo "$IP:80" 
sudo kubectl run mypodtstd --rm -it --image=busybox --restart=Never --env="IP=216.58.213.131" -- /bin/sh -c 'wget -O- $IP:80' | grep Connecting
````

output is 

````shell script
sylvain@sylvain-hp:~/docker-doctor$ IP="216.58.213.131"
sylvain@sylvain-hp:~/docker-doctor$ sudo kubectl run mypodtsta --rm -it --image=busybox --restart=Never -- wget -O- "$IP":80 | grep Connecting
Connecting to 216.58.213.131:80 (216.58.213.131:80)
Connecting to www.google.com (216.58.201.228:80)
sylvain@sylvain-hp:~/docker-doctor$ sudo kubectl run mypodtstb --rm -it --image=busybox --restart=Never --env="IP=$IP" -- wget -O- $IP:80 | grep Connecting
Connecting to 216.58.213.131:80 (216.58.213.131:80)
Connecting to www.google.com (216.58.201.228:80)
sylvain@sylvain-hp:~/docker-doctor$ unset IP
sylvain@sylvain-hp:~/docker-doctor$ sudo kubectl run mypodtstc --rm -it --image=busybox --restart=Never --env="IP=216.58.213.131" -- wget -O- $IP:80 | grep Connecting
pod default/mypodtstc terminated (Error)
sylvain@sylvain-hp:~/docker-doctor$ sudo kubectl run mypodtstc2 --rm -it --image=busybox --restart=Never --env="IP=216.58.213.131" -- echo "$IP:80"
:80
pod "mypodtstc2" deleted
sylvain@sylvain-hp:~/docker-doctor$ sudo kubectl run mypodtstd --rm -it --image=busybox --restart=Never --env="IP=216.58.213.131" -- /bin/sh -c 'wget -O- $IP:80' | grep Connecting

Connecting to 216.58.213.131:80 (216.58.213.131:80)
Connecting to www.google.com (216.58.201.228:80)
sylvain@sylvain-hp:~/docker-doctor$
sylvain@sylvain-hp:~/docker-doctor$ sudo kubectl run mypodtstd2 --rm -it --image=busybox --restart=Never --env="IP=216.58.213.131" -- /bin/sh -c 'echo $IP:80'
216.58.213.131:80
pod "mypodtstd2" deleted
sylvain@sylvain-hp:~/docker-doctor$
````

CQFD. It was using the var defined in the shell (mypodtstb), when it is unset (mypodtstc), we can see variable expansion does not occur.
Variable expansion is performed only if we have a shell (mypodtstd).
And consistent with: https://github.com/scoulomb/docker-doctor/blob/main/README.md#Link-other-projects

Used in [CKAD](https://github.com/scoulomb/CKAD-exercises/blob/master/a.core_concepts.md#get-nginx-pods-ip-created-in-previous-step-use-a-temp-busybox-image-to-wget-its-).

#### Note on temporary pod are not 

Note `i` is always mandatory here but  t become optional when injecting command directly.
 rm` if we want pod deletion. If rm is removed container will not be deleted automatically


#### We can use '/bin/sh -c'    

We can also do: [link section e - logging]

````shell script
k run toto --rm -it --image=busybox --restart=Never --env="IP=$IP" -- /bin/sh -c  'wget -O- $IP:80 | head -n 5'
````

Output is

````shell script
[17:34] ~
➤ k run toto --rm -it --image=busybox --restart=Never --env="IP=$IP" -- /bin/sh -c  'wget -O- $IP:80 | head -n 5'
Connecting to 172.17.0.5:80 (172.17.0.5:80)
writing to stdout
-                    100% |********************************|   612 <!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
 0:00:00 ETA
written to stdout
pod "toto" deleted
[17:34] ~
➤                                                             vagrant@archlinux
````

If omitting to give a name as `/bin/sh` is not a valid DNS name we would have an explicit error message. 
Using `sh` without bin is working.

##### Bash

In busybox we can not do bash but some images allows it, cf doc [here](https://kubernetes.io/docs/tasks/debug-application-cluster/get-shell-running-container/#getting-a-shell-to-a-container).
Nginx takes both.

````shell script
k run tutu --rm -it --image=nginx --restart=Never --env="IP=$IP" -- bash -c  'echo $IP:80'
````

Output is

````shell script
➤ k run tutu --rm -it --image=nginx --restart=Never --env="IP=$IP" -- bash -c
'echo $IP:80'
172.17.0.5:80
pod "tutu" deleted
````

#### Note in all cases name is optional if we provide a command to run but be careful

https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md#note-on-args-and-command
Pod name will be the first element of command and thus this will fail:
    
````
➤ k run --rm -it --image=busybox --restart=Never  -- wget -O- 172.17.0.4:8080 vagrant@archlinux
pod "wget" deleted
pod default/wget terminated (ContainerCannotRun)
OCI runtime create failed: container_linux.go:349: starting container process caused "exec: \"-O-\": executable file not found in $PATH": unknown
````

And reason of this is that, first arguments give the name and is removed from command to execute.
This can lead to failure as shown below
Note args and commands.
````shell script
➤ k run --image=busybox --restart=Never --dry-run -o yaml -- wget -O- 172.17.0.4:8080
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: wget
  name: wget
spec:
  containers:
  - args:
    - -O-
    - 172.17.0.4:8080
    image: busybox
    name: wget
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}

# if command: https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md#note-on-args-and-command
➤ k run --image=busybox --restart=Never --dry-run -o yaml --command -- wget -O- 172.17.0.4:8080

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: wget
  name: wget
spec:
  containers:
  - command:
    - -O-
    - 172.17.0.4:8080
    image: busybox
    name: wget
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}
➤ k run tutu --image=busybox --restart=Never --dry-run -o yaml -- wget -O- 172.17.0.4:8080
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: tutu
  name: tutu
spec:
  containers:
  - args:
    - wget
    - -O-
    - 172.17.0.4:8080
    image: busybox
    name: tutu
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}
````    

Thus when omitting the name and doing `-- bash wget`,  it is not running, bash is just used for the name.


#### We can also remove rm and it, and use logs

`k run busybox --image=busybox --restart=Never --env="IP=$IP" -- /bin/sh -c 'wget -O- $IP:80 | head -n 5 ;sleep 60' ; sleep 10; k logs busybox; k delete po busybox`
Need to do a sleep to have time to fetch logs
We can use command to avoid the sleep in container and not break entry point loop in busybox
As explained here: https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md#note-on-args-and-command
`k run busybox --image=busybox --restart=Never  --env="IP=$IP" --command -- /bin/sh -c 'wget -O- $IP:80 | head -n 5' ; sleep 10; k logs busybox; k delete po busybox`

Output is 

````shell script
➤ k run busybox --image=busybox --restart=Never --env="IP=$IP" -- /bin/sh -c 'wget -O- $IP:80 | head -n 5 ;sleep 60' ; sleep 10; k logs busybox; k delete po busybox
pod/busybox created
Connecting to 172.17.0.5:80 (172.17.0.5:80)
writing to stdout
-                    100% |********************************|   612  0:00:00 ETAwritten to stdout
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
pod "busybox" deleted
[17:40] ~
➤ k run busybox --image=busybox --restart=Never  --env="IP=$IP" --command -- /bin/sh -c 'wget -O- $IP:80 | head -n 5' ; sleep 10; k logs busybox; k delete po busybox
pod/busybox created
Connecting to 172.17.0.5:80 (172.17.0.5:80)
writing to stdout
-                    100% |********************************|   612  0:00:00 ETAwritten to stdout
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
pod "busybox" deleted
[17:41] ~
➤
````

### Injection - instructions in exec

Here we do --rm and -it whereas usually, we create the container and do an exec (with a sleep to not reach completion K)
USUALLY: 

#### Create pod 

````shell script
k run busybox --image=busybox --restart=Never --env="IP=$IP" -- sleep 3600
````

First line of this technique is a particular case of injecting instruction in run as shown [here](But-we-could-inject-command-directly).
So all comments above applied.
We can make same note for args and commands.

#### Executing cmd

##### Method A

````shell script
k exec -it busybox -- sh # (1)
wget -O- $IP:80 # (2)
````

In doc it is here: https://kubernetes.io/docs/tasks/debug-application-cluster/get-shell-running-container/#getting-a-shell-to-a-container
Where they use bash as explained [above](#Bash).

#### Method B

 xor (3) = (1) + (2) merged, inject command directly
k exec -it busybox -- wget -O- $IP:80 # (3)

Here `it` is not mandatory.
In doc it is here: https://kubernetes.io/docs/tasks/debug-application-cluster/get-shell-running-container/#running-individual-commands-in-a-container


#### Clean up
````shell script
k delete pod busybox
````


Method A looks like [Using interactive shell](#Using-interactive-shell).
Method B looks like [But we could inject command directly](But-we-could-inject-command-directly).

When using exec same apply as run command for instance we can and we could inject command directly 
we can do  `k exec -it busybox -- sh -c 'wget -O- 172.17.0.4:8080 -T 2'`
(works also with /bin/sh)

## Generate manifest

All k run can output a yaml by adding  `--dry-run -o yaml` before `--` of command 
Except if attached container (-i, -t option). And rm can only be used with attached.

````shell script
error: --dry-run can't be used with attached containers options (--attach, --stdin, or --tty)See 'kubectl run -h' for help and examples
```` 

Note on output generation

We can use it with `k apply -f`
- by outputting to a file 

```shell script
k run busybox --image=busybox --restart=Never --command --dry-run -o yaml -- /bin/sh -c 'wget -O- 172.17.0.4:8080' > o.yaml
k apply -f o.yaml
```
- Or one line
See https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/here-doc.md#combined-with-a-pipe-and---stdout

```
k run busybox --image=busybox --restart=Never --command --dry-run -o yaml -- /bin/sh -c 'wget -O- 172.17.0.4:8080' | k apply -f -
```

We can also use create instead of apply,
Note the difference between the 2 [here](https://stackoverflow.com/questions/47369351/kubectl-apply-vs-kubectl-create)

Useful for: https://github.com/dgkanatsios/CKAD-exercises/blob/master/a.core_concepts.md#create-the-pod-that-was-just-described-using-yaml

Though we can edit the yaml  (k explain pod.metadata.namespace) with correct namespace (but -n has no effect in k run cli)


## Force deletion

`k delete po --all --force --grace-period=0`

## Multicontainer

Select container with `-c` in `k exec`.
if `k run`, simplest is to genrate yaml and edit it.

In doc it is here: https://kubernetes.io/docs/tasks/debug-application-cluster/get-shell-running-container/#running-individual-commands-in-a-container


<!--
{15,30,31}/05/30/05 -> modif ok
All doc mapped OK and less complete, only second part:  Injection - instructions in exec
Move from f section to here ok, no structure change ctrlf will work
I use instruction as args/cmd
-->