# Run instructions into a container

It is an extension of this [CKAD question](https://github.com/dgkanatsios/CKAD-exercises/blob/master/f.services.md#get-the-pod-ips-create-a-temp-busybox-pod-and-trying-hitting-them-on-port-8080).
Except I will use nginx container exposing port 80.

Note (update with section a ok):


### Get the pod IPs. Create a temp busybox pod and trying hitting them on port 8080

<details><summary>show</summary>
<p>


```bash
kubectl get pods -l app=foo -o wide # 'wide' will show pod IPs
kubectl run busybox --image=busybox --restart=Never -it --rm -- sh
wget -O- POD_IP:8080 # do not try with pod name, will not work
# try hitting all IPs to confirm that hostname is different
exit
```

</p>
</details>

#### Note usage

Wide and label

#### i and t
- `i` for stdin, `t` for tty

#### we could inject command directly 

`k run mypod --rm -it --image=busybox --restart=Never -- wget -O- 172.17.0.4:8080`

and even give IP as en environment var by doing:

`IP=$(kubectl get pod nginx -o jsonpath='{.status.podIP}')` and add to run argument 
`--env="IP=$IP"` and use it `-- wget -O- $IP:80`.

Used in [CKAD](https://github.com/scoulomb/CKAD-exercises/blob/master/a.core_concepts.md#get-nginx-pods-ip-created-in-previous-step-use-a-temp-busybox-image-to-wget-its-).

`i` is still mandatory here but  t become optional. `rm` if we want pod deletion. If rm is removed container will not be deleted automatically

##### Note in all cases name is optional if we provide a command to run but be careful

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
And running bash will not work. 

##### We can use '/bin/sh -c'    

We can also do: [link section e - logging]

`k run toto --rm -it --image=busybox --restart=Never -- /bin/sh -c  'wget -O- 172.17.0.4:8080'`

If omitting to give a name as `/bin/sh` is not a valid DNS name we would have an explicit error message. 


##### We can also remove rm and it, and use logs

`k run busybox --image=busybox --restart=Never -- /bin/sh -c 'wget -O- 172.17.0.4:8080;sleep 60' ; sleep 10; k logs busybox; k delete po busybox`
Need to do a sleep to have time to fetch logs
We can use command to avoid the sleep in container and not break entry point loop in busybox
As explained here: https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md#note-on-args-and-command
`k run busybox --image=busybox --restart=Never --command -- /bin/sh -c 'wget -O- 172.17.0.4:8080' ; sleep 10; k logs busybox; k delete po busybox`

#### Here we do --rm and -it whereas usually:

we create the container and do an exec (with a sleep to not reach completion K)
USUALLY: 

````shell script

k run busybox --image=busybox --restart=Never -- sleep 3600 (or `k run busybox2 --image=busybox --restart=Never --  /bin/sh -c 'sleep 3600'`)
#k exec -it busybox -- sh (1)
#wget -O- 172.17.0.4:8080 (2)
# xor (3) = (1) + (2) merged, inject command directly
k exec -it busybox -- wget -O- 172.17.0.4:8080 # (3)
k delete pod busybox
````


we can do  `k exec -it busybox -- sh -c 'wget -O- 172.17.0.4:8080 -T 2'`
(works also with /bin/sh)

#### Generate manifest

All k run can output a yaml by adding  `--dry-run -o yaml` before `--` of command 
Except if attached container (-i, -t option). And rm can only be used with attached.

````shell script
error: --dry-run can't be used with attached containers options (--attach, --stdin, or --tty)See 'kubectl run -h' for help and examples
```` 

Note on output generation

We can it with k apply -f
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
Note the difference between the 2:
https://stackoverflow.com/questions/47369351/kubectl-apply-vs-kubectl-create

Useful for: https://github.com/dgkanatsios/CKAD-exercises/blob/master/a.core_concepts.md#create-the-pod-that-was-just-described-using-yaml
Though we can edit the yaml  (k explain pod.metadata.namespace) with correct namespace (but -n has no effect in k run cli)


#### Force deletion

`k delete po --all --force --grace-period=0`


15/05/30/05-< f -> modif ok

OK CLEAR- e2e optional in cheatsheet