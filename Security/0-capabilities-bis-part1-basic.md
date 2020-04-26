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
For this we need a local registry as explained here:
https://github.com/scoulomb/myk8s/blob/master/tooling/test-local-registry.sh

We push our custom image to registry (as ephemeral need to repush at each restart)
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

Same result as [Specific user with docker image with user 0](#Specific user with docker image with user 0)
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


Note CHOWN was already there by default, adding `CAP_FOWNER`, `CAP_SYS_TIME`, `CAP_NET_ADMIN`.
And we were not able to perform a chown in non root container...

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

It confirm that even if give container right capabilites but not root it still does not work.

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

###  Adding/removing capabilities to root containers

#### Constat

Conclusion of previous section is that even if container has correct capabilities,
non root user can not perform special operation.


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

#### Test adding and removing capabilities to root 

In [first test](#Docker-image-with-user-0)
Everything was possible except changing the date.
I will only allow to change the date.

As reminder root has following capa:

````buildoutcfg
````buildoutcfg
$ capsh --decode=00000000a80425fb
0x00000000a80425fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
````

I will drop cap_chown, cap_fowner, cap_fsetid, cap_net_bind_service,cap_net_raw.
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

- See [part 2](0-capabilities-bis-part2-admission-controller-setup.md)

Some notes:
- Found explanation SO question detailed here!
- Luska ok modified admin container -> Add `STS_TIME` as I did actually OK
- LFD make capa on non root user leading to confusion