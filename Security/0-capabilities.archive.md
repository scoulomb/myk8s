# Appendices

Traceroute (I excluded date setup) outside a container

## test on Ubuntu

### Laptop non sudo user

- Can do traceroute only with sudo otherwise ops not permitted
- grep Cap /proc/1/status | grep CapBnd
returns same value with sudo or not as related to proc 1
has the net_admin 
https://unix.stackexchange.com/questions/83322/which-process-has-pid-0
https://www.tldp.org/LDP/sag/html/proc-fs.html

### Vagrant

can do traceroute because root

# SecurityContext for containers


## Test with no user 
````
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  containers:
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
' > app.yaml

echo 'kubectl delete -f app.yaml
kubectl create -f app.yaml
sleep 5
kubectl exec -it app -- ps 
kubectl exec -it app -- grep Cap /proc/1/status | grep CapBnd
kubectl exec -it app -- traceroute google.fr
' > test_cap.sh

chmod u+x test_cap.sh
./test_cap.sh

````
Output is:

````
vagrant@k8sMaster:~$ chmod u+x test_cap.sh
vagrant@k8sMaster:~$ ./test_cap.sh
pod "app" deleted
pod/app created
PID   USER     TIME  COMMAND
    1 root      0:00 sleep 3600
    7 root      0:00 ps
CapBnd: 00000000a80425fb
traceroute to google.fr (216.58.213.131), 30 hops max, 46 byte packets
 1  10-0-2-15.kubernetes.default.svc.cluster.local (10.0.2.15)  0.007 ms  0.007 ms  0.096 ms
 2  10.0.2.2 (10.0.2.2)  0.006 ms  0.142 ms  0.113 ms
 3  *  *  *
 4  *^Ccommand terminated with exit code 130
````

And decoding

````
vagrant@k8sMaster:~$ capsh --decode=00000000a80425fb
0x00000000a80425fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
````

We can see:
- we are root
- but do not have all capabilities (NET_ADMIN, SYS_TIME)
- but can run a traceroute
cf. https://linux-audit.com/linux-capabilities-101/.
As running as root capabilitis are skipped



## Test with user at pod level

````
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
' > app.yaml

./test_cap.sh
````

Output is:

````
vagrant@k8sMaster:~$ ./test_cap.sh
pod "app" deleted
pod/app created
PID   USER     TIME  COMMAND
    1 1000      0:00 sleep 3600
    7 1000      0:00 ps
CapBnd: 00000000a80425fb
traceroute: socket: Operation not permitted
command terminated with exit code 1

````


We can see:
- we are not root but ser 1000
- but do not have all capabilities (NET_ADMIN, SYS_TIME)
- and can NOT run a traceroute
Because not root and do not have all capabilities


## Adding security context at container level

````
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
    securityContext:
      runAsUser: 2000
' > app.yaml

./test_cap.sh

````

Output is

````
vagrant@k8sMaster:~$ ./test_cap.sh
pod "app" deleted
pod/app created
PID   USER     TIME  COMMAND
    1 2000      0:00 sleep 3600
    6 2000      0:00 ps
CapBnd: 00000000a80425fb
traceroute: socket: Operation not permitted
command terminated with exit code 1
````

We can see:
- we are not user 1000 but 2000 (override)
- but do not have all capabilities (NET_ADMIN, SYS_TIME)
- and can NOT run a traceroute
Because not root and do not have all capabilities



## Adding capabilities

````
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
    securityContext:
      runAsUser: 2000
      capabilities : 
        add: ["NET_ADMIN", "SYS_TIME"]
' > app.yaml

./test_cap.sh

````

Output is:

````
vagrant@k8sMaster:~$ ./test_cap.sh
pod "app" deleted
pod/app created
PID   USER     TIME  COMMAND
    1 2000      0:00 sleep 3600
   12 2000      0:00 ps
CapBnd: 00000000aa0435fb
traceroute: socket: Operation not permitted
command terminated with exit code 1

````

And

````

vagrant@k8sMaster:~/app2$ capsh --decode=00000000aa0435fb
0x00000000aa0435fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_admin,cap_net_raw,cap_sys_chroot,cap_sys_time,cap_mknod,cap_audit_write,cap_setfcap

````

We can see:
- we are not user 1000 but 2000 (override)
- Have 2 new capabilities (NET_ADMIN, SYS_TIME)
- and can NOT run a traceroute
Which is unexpected: https://stackoverflow.com/questions/61043365/operation-not-permitted-when-performing-a-traceroute-from-a-container-deployed-i
Because if not root we added the capabilities

AllowPrivilege escalation seems to have no effect here.
# HERE
## As suggested in SO question 

busybox does not define user 2000

What if we define a user container?
Create user =>
- https://www.digitalocean.com/community/tutorials/how-to-create-a-sudo-user-on-ubuntu-quickstart
- https://stackoverflow.com/questions/27701930/add-user-to-docker-container
- https://stackoverflow.com/questions/39855304/how-to-add-user-with-dockerfile
- https://askubuntu.com/questions/94060/run-adduser-non-interactively

Associate user to uid =>
https://www.cyberciti.biz/faq/linux-change-user-group-uid-gid-for-all-owned-files/
#RUN usermod -u 2000 MYUSER 
No available use addgroup instead: https://superuser.com/questions/1395473/usermod-equivalent-for-alpine-linux
Actually use directly option in add user :https://www.busybox.net/downloads/BusyBox.html
adduser -u UID 

````
echo 'FROM busybox
RUN adduser --disabled-password --gecos "" MYUSER -u 2000
'> customBusybox.Dockerfile
sudo docker build . -f customBusybox.Dockerfile -t custombusybox
````
And then using this custom image.
For this we need a local registry as explained here:
https://github.com/scoulomb/myk8s/blob/master/tooling/test-local-registry.sh

We push our custom image to registry
````
registry_svc_ip=$(kubectl get svc | grep registry | awk '{ print $3 }')
echo $registry_svc_ip
sudo docker tag custombusybox $registry_svc_ip:5000/custombusybox
sudo docker push $registry_svc_ip:5000/custombusybox
````

In deployment we will reference the registry at this IP:

````
vagrant@k8sMaster:~
$ echo $registry_svc_ip
10.106.68.188

````
So that

````
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: busy
    image: 10.106.68.188:5000/custombusybox
    command:
     - sleep
     - "3600"
    securityContext:
      runAsUser: 2000
      capabilities : 
        add: ["NET_ADMIN", "SYS_TIME"]
' > app.yaml

./test_cap.sh

````
The result is same as per comment 
Stop here far beyond.OK.
