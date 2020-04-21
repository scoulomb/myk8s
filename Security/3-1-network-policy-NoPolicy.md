# Network policy

## Test with no network policy.

We will reuse pod from  [capabilites tutorial - Adding security context at container level](0-capabilities.archive.md#Adding-security-context-at-container-level).
As we want to test ingress and egress, we will:
- add a nginx container to test ingress.
- provide a service to access the wevserver

### Add a nginx container to test ingress

````buildoutcfg
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: webserver
    image: nginx
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
    securityContext:
      runAsUser: 2000
' > app.yaml

k delete -f app.yaml
k create -f app.yaml
````

There is a crashloopback :

````buildoutcfg
$ k get pods | grep app
app                         1/2     CrashLoopBackOff   4          8m36s

$ k get event | grep Back-off
3m38s       Warning   BackOff                   pod/app                         Back-off restarting failed container

$ k logs app webserver
2020/04/13 14:28:58 [warn] 1#1: the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
nginx: [warn] the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
2020/04/13 14:28:58 [emerg] 1#1: mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
````

As described in [capabilities](0-capabilities.archive.md), we will remove security context to run as root.

Thus 

````buildoutcfg
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: webserver
    image: nginx
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
' > app.yaml

k delete -f app.yaml
k create -f app.yaml
````

It is now ok:

````buildoutcfg
$ k get pods | grep app
app                         2/2     Running   0          22s
vagrant@k8sMaster:~/toto
````


### Create a service

We will create a nodeport service.
We can refer to service section [here](../Services/service_deep_dive.md#NodePort).
Except here it is done at pod level and not deployment.

````buildoutcfg
k expose pod app --type=NodePort --port=80
````

Output is

````buildoutcfg
error: couldn't retrieve selectors via --selector flag or introspection: the pod has no labels and cannot be exposed
See 'kubectl expose -h' for help and examples
````

We need to add a label (svc selector) in the pod to make it work.

````buildoutcfg
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
  labels:
    svc-name: app
spec:
  containers:
  - name: webserver
    image: nginx
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
' > app.yaml

k delete -f app.yaml
k create -f app.yaml
````

Then do


````buildoutcfg
k expose pod app --type=NodePort --port=80
````

Output is:

````buildoutcfg
$ k expose pod app --type=NodePort --port=80
Error from server (InternalError): Internal error occurred: failed to allocate a nodePort: range is full
````

This is because in service section [here](../Services/service_deep_dive.md#NodePort).
> To ensure NodePort is in the range of port forwarded by the VM, we will add [following line](http://www.thinkcode.se/blog/2019/02/20/kubernetes-service-node-port-range) `--service-node-port-range=32000-32000` in command section of `/etc/kubernetes/manifests/kube-apiserver.yaml`

I removed line `--service-node-port-range=32000-32000`
It restart the kube-api server.

Then :

````buildoutcfg
$ k expose pod app --type=NodePort --port=80
service/app exposed

vagrant@k8sMaster:~/toto
$ k get svc app -o yaml | grep -C 2 selector
    protocol: TCP
    targetPort: 80
  selector:
    svc-name: app
  sessionAffinity: None
````

We can the selector is reused!

It is also possible to do it manually with the yaml or with the svc command:

````buildoutcfg
k delete svc app
k create svc nodeport app --tcp=80
````

If I do a curl:

````buildoutcfg
vagrant@k8sMaster:~/toto
$ k get svc | grep app
app               NodePort    10.105.171.114   <none>        80:32681/TCP                         33s
vagrant@k8sMaster:~/toto
$ curl  10.105.171.114
curl: (7) Failed to connect to 10.105.171.114 port 80: Connection refused
````

[Here in service section](../Services/service_deep_dive.md#Use-a-different-port), we remind that
> by default `port = target port`

Let's inspect the service:

````buildoutcfg
$ k get svc app -o yaml | grep -C 2 selector
    protocol: TCP
    targetPort: 80
  selector:
    app: app
  sessionAffinity: None
```` 

We can see the selector is not accurate, we should use `svc-name: app` (we could have chosen the name smartly to make it work). 
I will edit the service to match it and change also the node port to 32000 (which is forwarded in my VM and because I want to use this port).
Note it is also possible to limit the range shown with ``--service-node-port-range=32000-32000` as shown before.

````buildoutcfg
# k edit svc app
# if port 32000 already in use delete this svc
vagrant@k8sMaster:~/toto
$ k get svc app -o yaml | grep -C 2 nodePort
  ports:
  - name: "80"
    nodePort: 32000
    port: 80
    protocol: TCP
vagrant@k8sMaster:~/toto
$ k get svc app -o yaml | grep -C 2 selector
    protocol: TCP
    targetPort: 80
  selector:
    svc-name: app
  sessionAffinity: None

$ k get svc | grep app
app               NodePort    10.105.171.114   <none>        80:32000/TCP                         15m

$ curl  10.105.171.114
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
````

As it is a NodePort I can also do `curl` outside of the VM (and also because port 32000 is forwarded in `vagrant` file):

````buildoutcfg
scoulomb@outsideVM:/mnt/c/git_pub/myk8s
$ curl localhost:32000
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
````

Ingress is working.

What about egress?

````buildoutcfg
$ k exec -it -c busy app -- /bin/sh
/ # nc -vz 127.0.0.1 80
127.0.0.1 (127.0.0.1:80) open
/ # nc -vz www.mozilla.org 80
www.mozilla.org (104.16.143.228:80) open
/ # exit
````

Egress is working