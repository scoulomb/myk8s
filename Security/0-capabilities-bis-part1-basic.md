# Capabilities

## Run with default

### Docker image with user 0

````buildoutcfg
source capa_test.sh
kubectl delete pod pod-with-defaults
kubectl run pod-with-defaults --image alpine --restart Never -- /bin/sleep 999999
capa_test pod-with-defaults
````

Output is

````buildoutcfg
vagrant@k8sMaster:~
$ capa_test pod-with-defaults
+ capa_test pod-with-defaults
+ set -x
+ kubectl exec pod-with-defaults -- id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
+ grep --color=auto CapBnd
+ kubectl exec pod-with-defaults -- grep Cap /proc/1/status
CapBnd: 00000000a80425fb
+ kubectl exec pod-with-defaults -- traceroute 127.0.0.1
traceroute to 127.0.0.1 (127.0.0.1), 30 hops max, 46 byte packets
 1  localhost (127.0.0.1)  0.513 ms  0.004 ms  0.004 ms
+ kubectl exec pod-with-defaults -- date +%T -s 12:00:00
date: can't set date: Operation not permitted
12:00:00
+ kubectl exec pod-with-defaults -- chmod 777 home
+ echo 0
0
+ kubectl exec pod-with-defaults -- chown nobody /
+ echo 0
0
````

- The User which is used is the one defined in the container image, which is root 0.
- I can perform a traceroute
- I can not change the date (I did not expect this as I am root, we will see why)
- I can perform chmod
- and chown

### Run with default an image where a user is defined

````
echo 'FROM alpine
USER 7777
'> customAlpine.Dockerfile
sudo docker build . -f customAlpine.Dockerfile -t customalpine
````

And then using this custom image.
For this we need a local registry as explained here (or use alternative described [here](../README.md)):
https://github.com/scoulomb/myk8s/blob/master/tooling/test-local-registry.sh


We push our custom image to registry (as ephemeral need to repush at each restart). We can use image-pull-policy never as alternative.
I could use dockerhub instead.

````
export registry_svc_ip=$(kubectl get svc | grep registry | awk '{ print $3 }')
echo $registry_svc_ip
sudo docker tag customalpine $registry_svc_ip:5000/customalpine
sudo docker push $registry_svc_ip:5000/customalpine
````

In deployment we will reference the registry at this IP:

````
vagrant@k8sMaster:~
$ echo $registry_svc_ip
10.106.68.188

````
So that

````buildoutcfg
kubectl delete pod pod-with-defaults-custom
kubectl run pod-with-defaults-custom --image $registry_svc_ip:5000/customalpine --restart Never -- /bin/sleep 999999
````

Here output is

````buildoutcfg
vagrant@k8sMaster:~
$ capa_test pod-with-defaults-custom
+ capa_test pod-with-defaults-custom
+ set -x
+ kubectl exec pod-with-defaults-custom -- id
uid=7777 gid=0(root)
+ grep --color=auto CapBnd
+ kubectl exec pod-with-defaults-custom -- grep Cap /proc/1/status
CapBnd: 00000000a80425fb
+ kubectl exec pod-with-defaults-custom -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-with-defaults-custom -- date +%T -s 12:00:00
12:00:00
date: can't set date: Operation not permitted
+ kubectl exec pod-with-defaults-custom -- chmod 777 home
chmod: home: Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-with-defaults-custom -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1
````

- The use id Id is the one specified in the docker image which is now 7777.
However It still belongs to root group
- I can not perform traceroute as I am not root
- I can not change the date (still)
- I can not perform chmod as I am not root
- I can not perform chown as I am not root 

we will see later that w have the capas by default, for instance chwon but still we can not perform these operations.

## For container to be runned as a specific user 

Note guest user is 405 in alpine

### Specific user with docker image with user 0
````buildoutcfg
kubectl delete pod pod-as-user-guest
echo '
apiVersion: v1
kind: Pod
metadata:
  name: pod-as-user-guest
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 405 ' > pod-as-user-guest.yaml
                             
k  create -f  pod-as-user-guest.yaml  
````

Then output is 

````buildoutcfg
vagrant@k8sMaster:~
$ capa_test pod-as-user-guest
+ capa_test pod-as-user-guest
+ set -x
+ kubectl exec pod-as-user-guest -- id
uid=405(guest) gid=100(users)
+ kubectl exec pod-as-user-guest -- grep Cap /proc/1/status
+ grep --color=auto CapBnd
CapBnd: 00000000a80425fb
+ kubectl exec pod-as-user-guest -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-as-user-guest -- date +%T -s 12:00:00
12:00:00
date: can't set date: Operation not permitted
+ kubectl exec pod-as-user-guest -- chmod 777 home
chmod: home: Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-as-user-guest -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1
````                   

- User in docker (root) is overriden and it does not belong to root group.
- I can not perform traceroute as I am not root
- I can not change the date (still)
- I can not perform chmod as I am not root
- I can not perform chown as I am not root 

### Specific user with docker image with user 7777
What about custom image:

````buildoutcfg
k  delete pod pod-as-user-guest-custom
echo '
apiVersion: v1
kind: Pod
metadata:
  name: pod-as-user-guest-custom
spec:
  containers:
  - name: main
    image: 10.106.68.188:5000/customalpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 405 ' > pod-as-user-guest-custom.yaml
                             
k  create -f  pod-as-user-guest-custom.yaml

````

Output is 

````buildoutcfg
vagrant@k8sMaster:~
$ capa_test  pod-as-user-guest-custom
+ capa_test pod-as-user-guest-custom
+ set -x
+ kubectl exec pod-as-user-guest-custom -- id
uid=405(guest) gid=100(users)
+ kubectl exec pod-as-user-guest-custom -- grep Cap /proc/1/status
+ grep --color=auto CapBnd
CapBnd: 00000000a80425fb
+ kubectl exec pod-as-user-guest-custom -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-as-user-guest-custom -- date +%T -s 12:00:00
12:00:00
date: can't set date: Operation not permitted
+ kubectl exec pod-as-user-guest-custom -- chmod 777 home
chmod: home: Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-as-user-guest-custom -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1
                                                                      
````

Same result as [Specific user with docker image with user 0](#Specific-user-with-docker-image-with-user-0)
Where we can clearly user in image is overriden.

Note it is also possible to define sec context at pod level in `spec.securityContext`.
Container level overrides pod level.

## Adding capabilities

Some doc:
- http://man7.org/linux/man-pages/man7/capabilities.7.html
- https://github.com/docker/labs/tree/master/security/capabilities#step-3-testing-docker-capabilities


### Constat

Taking [this pod](#specific-user-with-docker-image-with-user-0).
We were not allowed to perform any operations which is logical since not root.

And if we compare with root we can see it has the same capabilities
If we decode its capabilites, we can see the right this container has:
````buildoutcfg
$ capsh --decode=00000000a80425fb
0x00000000a80425fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
````


###  Adding capabilities to non root containers

Note `CHOWN`, `NET_RAW` was already there by default.
`CHOWN` enable to do a chown wile `NET_RAW` enable to perform a traceroute.
This is proven [below](#Test-adding-and-removing-capabilities-to-root-in-Kubernetes)

Still we were not able to perform a chown/traceroute in non root container...

Adding more capabilities in same area: `CAP_FOWNER`, `CAP_SYS_TIME`, `CAP_NET_ADMIN`.

````buildoutcfg
k delete pod pod-as-user-guest-with-new-capa
echo '
apiVersion: v1
kind: Pod
metadata:
  name: pod-as-user-guest-with-new-capa
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 405
      capabilities : 
        add: ["NET_ADMIN", "SYS_TIME", "CHOWN", "FOWNER", "FSETID"]' > pod-as-user-guest-with-new-capa.yaml
                             
k create -f  pod-as-user-guest-with-new-capa.yaml

````

Then 

````buildoutcfg
vagrant@k8sMaster:~
$ capa_test pod-as-user-guest-with-new-capa
+ capa_test pod-as-user-guest-with-new-capa
+ set -x
+ kubectl exec pod-as-user-guest-with-new-capa -- id
uid=405(guest) gid=100(users)
+ kubectl exec pod-as-user-guest-with-new-capa -- grep Cap /proc/1/status
+ grep --color=auto CapBnd
CapBnd: 00000000aa0435fb
+ kubectl exec pod-as-user-guest-with-new-capa -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-as-user-guest-with-new-capa -- date +%T -s 12:00:00
date: can't set date: Operation not permitted
12:00:00
+ kubectl exec pod-as-user-guest-with-new-capa -- chmod 777 home
chmod: home: Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-as-user-guest-with-new-capa -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1
```` 

Still not able to do traceroute or chown,

It confirm that even if give container more capabilities but not root it still does not work.

New capa are visible here:

````buildoutcfg
vagrant@k8sMaster:~
$ k get pods  pod-as-user-guest-with-new-capa -o yaml | grep -A 7 capabilities
+ grep --color=auto -A 7 capabilities
+ kubectl get pods pod-as-user-guest-with-new-capa -o yaml
      capabilities:
        add:
        - NET_ADMIN
        - SYS_TIME
        - CHOWN
        - FOWNER
        - FSETID
      runAsUser: 405

````

We can capsh value changed to `00000000aa0435fb`.

And that it includes new capa:
````buildoutcfg
scoulomb@NCEL75539:/mnt/c/Users/scoulombel
$ capsh --decode=00000000aa0435fb | grep net_admin
0x00000000aa0435fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_admin,cap_net_raw,cap_sys_chroot,cap_sys_time,cap_mknod,cap_audit_write,cap_setfcap
scoulomb@NCEL75539:/mnt/c/Users/scoulombel
$ capsh --decode=00000000aa0435fb | grep chown
0x00000000aa0435fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_admin,cap_net_raw,cap_sys_chroot,cap_sys_time,cap_mknod,cap_audit_write,cap_setfcap
````


Using busybox leads to same result

````shell script
k delete pod pod-as-user-guest-with-new-capa
echo '
apiVersion: v1
kind: Pod
metadata:
  name: pod-as-user-guest-with-new-capa-busybox
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 405
      capabilities : 
        add: ["NET_ADMIN", "SYS_TIME", "CHOWN", "FOWNER", "FSETID"]' > pod-as-user-guest-with-new-capa-busybox.yaml
                             
k create -f  pod-as-user-guest-with-new-capa-busybox.yaml
````
output is 

````shell script
root@sylvain-hp:/home/sylvain/ubuntu# k exec -it pod-as-user-guest-with-new-capa-busybox -- traceroute 127.0.0.1
+ kubectl exec -it pod-as-user-guest-with-new-capa-busybox -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
````
###  Adding/removing capabilities to root containers

#### Constat

Conclusion of previous section is that even if container has correct capabilities,
Non root user can still not perform special operation.
This behavior is actually distribution dependent (see [SO question](#part-2-so-comment)).

#### We can remove capabilities to root container:
This is confirmed by this quick test:

- Container root with no chown capa (operation not permitted) and with it (working)
````buildoutcfg
vagrant@k8sMaster:~
$ sudo docker container run --rm -it --cap-drop ALL alpine chown nobody /
chown: /: Operation not permitted
vagrant@k8sMaster:~
$ sudo docker container run --rm -it --cap-drop ALL --cap-add CHOWN alpine chown nobody /
# no output means it worked
````

- Whereas container non root with chown capa is not working
````buildoutcfg
vagrant@k8sMaster:~
$ sudo docker container run --rm -it --cap-drop ALL --cap-add CHOWN 10.106.68.188:5000/customalpine chown nobody /
chown: /: Operation not permitted
````

As a conclusion capabilities are not bypassed by root but enable to give less rigth to root user.
This is what is suggested here: https://www.redhat.com/en/blog/secure-your-containers-one-weird-trick

So I reached the same conclusion as [first version](0-capabilities.archive.md).
All info in first version is there.
And this answer my question in [SO](https://stackoverflow.com/questions/61043365/operation-not-permitted-when-performing-a-traceroute-from-a-container-deployed-i).

#### Test adding and removing capabilities to root in Kubernetes

In [first test](#Docker-image-with-user-0)
Everything was possible except changing the date.
I will only allow to change the date.

As reminder root has following capa:

````buildoutcfg
````buildoutcfg
$ capsh --decode=00000000a80425fb
0x00000000a80425fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
````

I will drop cap_chown, cap_net_raw.
I will add cap_sys_time


````buildoutcfg
k delete pod pod-root-with-modified-capa
echo '
apiVersion: v1
kind: Pod
metadata:
  name: pod-root-with-modified-capa
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      capabilities : 
        add: ["SYS_TIME"]
        drop: ["CHOWN", "NET_RAW"]' > pod-root-with-modified-capa.yaml
                             
k create -f  pod-root-with-modified-capa.yaml
````

Output is:

````buildoutcfg
vagrant@k8sMaster:~
$ capa_test pod-root-with-modified-capa
+ capa_test pod-root-with-modified-capa
+ set -x
+ kubectl exec pod-root-with-modified-capa -- id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
+ grep --color=auto CapBnd
+ kubectl exec pod-root-with-modified-capa -- grep Cap /proc/1/status
CapBnd: 00000000aa0405fa
+ kubectl exec pod-root-with-modified-capa -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-root-with-modified-capa -- date +%T -s 12:00:00
12:00:00
+ kubectl exec pod-root-with-modified-capa -- chmod 777 home
+ echo 0
0
+ kubectl exec pod-root-with-modified-capa -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1
````

- We are root
- But we can not perform a traceroute, because we dropped `NET_RAW`
- We can now change time which was not possible by default in [first test](#Docker-image-with-user-0).
It is because we add `SYS_TIME` capabilities.
- We can still perform a chmod. It is because root can always write to file
See [here](https://superuser.com/questions/104015/removing-write-permission-does-not-prevent-root-from-writing-to-the-file).
But it does not bypass capa as I could read.
- I can not perform chown because we dropped `CHOWN` 


#### Side note based on SO answer and distribution dependent behavior

#### Part 1

As spotted by SO question.
The behavior which prevent from running a traceroute when not root is distribution dependent (busybox,alpine != ubuntu).
Cf answer here: https://stackoverflow.com/questions/61043365/operation-not-permitted-when-performing-a-traceroute-from-a-container-deployed-i/61396011#61396011

Here I have a Ubuntu container baked with root uid, and which runs with a specific user id.
(Note test is on minikube, I run with a root kubectl user to not have psp applied).

I will use image pull policy to never to not deploy an artifactroy ([see readme](../README.md)).

````buildoutcfg
mkdir ubuntu
cd ubuntu 
echo 'FROM ubuntu 
RUN apt-get update
RUN apt-get install traceroute
'> customUbuntu.Dockerfile
sudo docker build . -f customUbuntu.Dockerfile -t customubuntu

echo '
apiVersion: v1
kind: Pod
metadata:
  name: pod-nonroot-with-modified-capa
spec:
  containers:
  - name: main
    image: customubuntu
    imagePullPolicy: Never
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 2000
      capabilities:
        add: ["SYS_TIME"]
        drop: ["CHOWN", "NET_RAW"]' > pod-nonroot-with-modified-capa.yaml 
sudo su                             
kubectl  create -f  pod-nonroot-with-modified-capa.yaml 
````

If error when sourcing copy/past, capa_test.sh content.

Output is:

````buildoutcfg
root@sylvain-hp:/home/sylvain/ubuntu# capa_test pod-nonroot-with-modified-capa
+ capa_test pod-nonroot-with-modified-capa
+ set -x
+ kubectl exec pod-nonroot-with-modified-capa -- id
uid=2000 gid=0(root) groups=0(root)
+ grep --color=auto CapBnd
+ kubectl exec pod-nonroot-with-modified-capa -- grep Cap /proc/1/status
CapBnd: 00000000aa0405fa
+ kubectl exec pod-nonroot-with-modified-capa -- traceroute 127.0.0.1
traceroute to 127.0.0.1 (127.0.0.1), 30 hops max, 60 byte packets
 1  localhost (127.0.0.1)  0.030 ms  0.011 ms  0.008 ms
+ kubectl exec pod-nonroot-with-modified-capa -- date +%T -s 12:00:00
12:00:00
date: cannot set date: Operation not permitted
command terminated with exit code 1
+ true
+ kubectl exec pod-nonroot-with-modified-capa -- chmod 777 home
chmod: changing permissions of 'home': Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-nonroot-with-modified-capa -- chown nobody /
chown: changing ownership of '/': Operation not permitted
command terminated with exit code 1
+ echo 1
1
````

I can perform a traceroute even if not root.
But even when dropping more capabilities

````buildoutcfg
echo '
apiVersion: v1
kind: Pod
metadata:
  name: customubuntudrop3capa
spec:
  containers:
  - name: main
    image: customubuntu
    imagePullPolicy: Never
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 2000 
      capabilities:
        drop: ["NET_RAW", "NET_BIND_SERVICE", "NET_ADMIN"]' > customubuntu_drop_3_capa.yaml
                             
kubectl  create -f customubuntu_drop_3_capa.yaml
````

Output is 


````buildoutcfg
root@sylvain-hp:/home/sylvain/ubuntu# capa_test customubuntudrop3capa
+ capa_test customubuntudrop3capa
+ set -x
+ kubectl exec customubuntudrop3capa -- id
uid=2000 gid=0(root) groups=0(root)
+ grep --color=auto CapBnd
+ kubectl exec customubuntudrop3capa -- grep Cap /proc/1/status
CapBnd: 00000000a80401fb
+ kubectl exec customubuntudrop3capa -- traceroute 127.0.0.1
traceroute to 127.0.0.1 (127.0.0.1), 30 hops max, 60 byte packets
 1  localhost (127.0.0.1)  0.457 ms  0.414 ms  0.391 ms
+ kubectl exec customubuntudrop3capa -- date +%T -s 12:00:00
date: cannot set date: Operation not permitted
12:00:00
command terminated with exit code 1
+ true
+ kubectl exec customubuntudrop3capa -- chmod 777 home
chmod: changing permissions of 'home': Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec customubuntudrop3capa -- chown nobody /
chown: changing ownership of '/': Operation not permitted
command terminated with exit code 1
+ echo 1
1
````

and with 

````buildoutcfg
$ capsh --decode=00000000a80401fb
0x00000000a80401fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
````

Same if run as root (uid 0)

##### Part 2: SO comment

So comment to answer in SO
> This helps me understand a bit more. I agree that for busybox/alpine image it is not possible to run a traceroute when not root whatever the capabilities. However it is possible to drop capabilities(*) and prevent root user from doing a traceroute. However I do not fully agree with last part of your answer because it seems that with the ubuntu image even when  explicitly dropping ["NET_RAW", "NET_BIND_SERVICE", "NET_ADMIN"], with root or non root user I can still perform a traceroute. 

<!-- Note default capa with default psp does not drop NET_RAW, not rechecked but ok --> 
(*) always tested with Alpine image in this [section](#test-adding-and-removing-capabilities-to-root-in-kubernetes).

<!-- Added answer on 28apr19 ok - come back only if update;
it summarize three last point OK-->



##### Part 3: TCP traceroute

By default we always did a UDP traceroute.
It is possible to perform a TCP traceroute.
For instance `traceroute -T -p 443 mozilla.org`.

Output of

````shell script
kubectl exec pod-nonroot-with-modified-capa -- traceroute -T -p 443 mozilla.org
kubectl exec customubuntudrop3capa -- traceroute -T -p 443 mozilla.org
````


is 

````shell script
root@sylvain-hp:/home/sylvain/ubuntu# kubectl exec pod-nonroot-with-modified-capa -- traceroute -T -p 443 mozilla.org
+ kubectl exec pod-nonroot-with-modified-capa -- traceroute -T -p 443 mozilla.org
You do not have enough privileges to use this traceroute method.
socket: Operation not permitted
command terminated with exit code 1
root@sylvain-hp:/home/sylvain/ubuntu# kubectl exec customubuntudrop3capa -- traceroute -T -p 443 mozilla.org
+ kubectl exec customubuntudrop3capa -- traceroute -T -p 443 mozilla.org
You do not have enough privileges to use this traceroute method.
socket: Operation not permitted
command terminated with exit code 1
````

But if I replace `drop` by `add` in customubuntudrop3capa:

````shell script
echo '
apiVersion: v1
kind: Pod
metadata:
  name: customubuntuadd3capa
spec:
  containers:
  - name: main
    image: customubuntu
    imagePullPolicy: Never
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 2000 
      capabilities:
        add: ["NET_RAW", "NET_BIND_SERVICE", "NET_ADMIN"]' > customubuntu_add_3_capa.yaml
                             
kubectl  create -f customubuntu_add_3_capa.yaml
````

and run 

````shell script
kubectl exec customubuntuadd3capa -- traceroute -T -p 443 mozilla.org
````

output is 

````shell script
root@sylvain-hp:/home/sylvain/ubuntu# kubectl exec customubuntuadd3capa -- traceroute -T -p 443 mozilla.org
+ kubectl exec customubuntuadd3capa -- traceroute -T -p 443 mozilla.org
You do not have enough privileges to use this traceroute method.
socket: Operation not permitted
command terminated with exit code 1
````

It is still not allowed.
We have to be root.
So removing `runAsUser`

````shell script
echo '
apiVersion: v1
kind: Pod
metadata:
  name: customubuntuadd3capaandroot
spec:
  containers:
  - name: main
    image: customubuntu
    imagePullPolicy: Never
    command: ["/bin/sleep", "999999"]
    securityContext:
      capabilities:
        add: ["NET_RAW", "NET_BIND_SERVICE", "NET_ADMIN"]' > customubuntu_add_3_capa_and_root.yaml
                             
kubectl  create -f customubuntu_add_3_capa_and_root.yaml
````

and 

````shell script
kubectl exec customubuntuadd3capaandroot -- traceroute -T -p 443 mozilla.org
````


ouptut is

````shell script
root@sylvain-hp:/home/sylvain/ubuntu# kubectl exec customubuntuadd3capaandroot -- traceroute -T -p 443 127.0.0.1
+ kubectl exec customubuntuadd3capaandroot -- traceroute -T -p 443 127.0.0.1
traceroute to 127.0.0.1 (127.0.0.1), 30 hops max, 60 byte packets
 1  localhost (127.0.0.1)  0.247 ms  0.224 ms  0.217 ms
````

If we drop capa of root user

````shell script
echo '
apiVersion: v1
kind: Pod
metadata:
  name: customubuntudrop3capaandroot
spec:
  containers:
  - name: main
    image: customubuntu
    imagePullPolicy: Never
    command: ["/bin/sleep", "999999"]
    securityContext:
      capabilities:
        drop: ["NET_RAW", "NET_BIND_SERVICE", "NET_ADMIN"]' > customubuntu_drop_3_capa_and_root.yaml
                             
kubectl  create -f customubuntu_drop_3_capa_and_root.yaml
````

and 

````shell script
kubectl exec customubuntudrop3capaandroot -- traceroute -T -p 443 mozilla.org
````


ouptut is

````shell script
root@sylvain-hp:/home/sylvain/ubuntu# kubectl exec customubuntudrop3capaandroot -- traceroute -T -p 443 mozilla.org
+ kubectl exec customubuntudrop3capaandroot -- traceroute -T -p 443 mozilla.org
You do not have enough privileges to use this traceroute method.
socket: Operation not permitted
command terminated with exit code 1
````

Conclusion is:
 - TCP traceroute requires root and right capabilities.
 - Thus **TCP** traceroute with ubuntu follows same [pattern](#part-2-so-comment) as **UDP** Alpine traceroute
 > For alpine image it is not possible to run a traceroute when not root whatever the capabilities.
>  However it is possible to drop capabilities and prevent root user from doing a traceroute

For those test we were in that case ["Specific user with docker image with user 0"](#specific-user-with-docker-image-with-user-0).

- See [part 2](0-capabilities-bis-part2-admission-controller-setup.md)

Some notes:
- Found explanation SO question detailed here!
- Luska ok modified admin container -> Add `STS_TIME` as I did actually OK
- LFD make capa on non root user leading to confusion

<!-- use ssh -->