# Capabilities -  Pod security policy

This follows part 4.
Assume I want to run this pod.

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


We are in crashloopback off

````buildoutcfg
root@minikube:~# k get pods | grep app
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pods
+ grep --color=auto app
app                          1/2     Error     5          6m23s

root@minikube:~# k logs -f app -c webserver
+ kubectl --as=system:serviceaccount:default:default-non-root -n default logs -f app -c webserver
2020/04/26 15:08:19 [warn] 1#1: the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
nginx: [warn] the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
2020/04/26 15:08:19 [emerg] 1#1: mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
root@minikube:~#
````

# Solution 1: run as root

To run as root we would have to:
- use a privileged user to create the container
- or modify the PSP

This is equivalent to what we did here:
[section 3-1](./3-1-network-policy-NoPolicy.md#Add-a-nginx-container-to-test-ingress).
Where we remove the runAs at pod level and we had no psp override as shown in part 4.

Unfortunately it is sometimes not possible to do this as need to respect psp.

````buildoutcfg
root@minikube:~# kadm create -f app.yaml
+ kubectl -n default create -f app.yaml
pod/app created
root@minikube:~# k get pods  | grep app
+ grep --color=auto app
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pods
app                          2/2     Running   0          10s
````

# Solution 2: Mount empty dir volume

Use an [empty dir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir) volume.

````buildoutcfg
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app-vol
spec:
  containers:
  - name: webserver
    image: nginx
    volumeMounts:
    - mountPath: /var/cache/nginx
      name: cache-volume
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
  volumes:
  - name: cache-volume
    emptyDir: {}
' > app-vol.yaml

k delete -f app-vol.yaml
k create -f app-vol.yaml
````

Output is 

````buildoutcfg
root@minikube:~# k create -f app-vol.yaml
+ kubectl --as=system:serviceaccount:default:default-non-root -n default create -f app-vol.yaml
pod/app-vol created
root@minikube:~# k logs -f app-vol -c webserver
+ kubectl --as=system:serviceaccount:default:default-non-root -n default logs -f app-vol -c webserver
2020/04/26 15:26:00 [warn] 1#1: the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
nginx: [warn] the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
2020/04/26 15:26:00 [emerg] 1#1: bind() to 0.0.0.0:80 failed (13: Permission denied)
nginx: [emerg] bind() to 0.0.0.0:80 failed (13: Permission denied)
root@minikube:~# capa_test app-vol
````

We have another error (capa on network) but directory on issue is fixed.


# Solution 3: Modify docker image 

```buildoutcfg
mkdir mynginx
cd mynginx

echo ' 
FROM nginx
RUN mkdir -p /var/cache/nginx && chmod 777 /var/cache/nginx
' > mynginx.Dockerfile

sudo docker build -f mynginx.Dockerfile -t mynginx .
```

As I do not have a local registry in my minikube setup I will use docker hub.

```buildoutcfg
docker tag mynginx scoulomb/mynginx
docker login -u scoulomb
docker push scoulomb/mynginx
```
I do have authentication issue on docker hub. 
I would like to pull image locally and not go to an artifactory.
If replacing image nginx by mynginx in pods sepc it will go to an artifactory by default and found nothing.
To force to use image on node we can use image pull policy.
This avoids using an artifactory (we will show local artifactory deployment in other section when not using minikube).

So 


```buildoutcfg
echo 'apiVersion: v1
kind: Pod
metadata:
  name: mynginx
spec:
  containers:
  - name: webserver
    image: mynginx
    imagePullPolicy: Never
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
' > mynginx.yaml

k delete -f mynginx.yaml
k create -f mynginx.yaml
```

We can see image is pulled locally (my built)

```buildoutcfg
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  <unknown>         default-scheduler  Successfully assigned default/mynginx to minikube
  Normal   Pulling    25s               kubelet, minikube  Pulling image "busybox"
  Normal   Started    22s               kubelet, minikube  Started container busy
  Normal   Pulled     22s               kubelet, minikube  Successfully pulled image "busybox"
  Normal   Created    22s               kubelet, minikube  Created container busy
  Normal   Created    6s (x3 over 26s)  kubelet, minikube  Created container webserver
  Normal   Started    6s (x3 over 25s)  kubelet, minikube  Started container webserver
  Normal   Pulled     6s (x3 over 26s)  kubelet, minikube  Container image "mynginx" already present on machine
  Warning  BackOff    5s (x3 over 19s)  kubelet, minikube  Back-off restarting failed container
```


and finally 

```buildoutcfg
root@minikube:~/mynginx/mynginx# k logs -f mynginx -c webserver
+ kubectl --as=system:serviceaccount:default:default-non-root -n default logs -f mynginx -c webserver
2020/04/26 16:23:07 [warn] 1#1: the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
nginx: [warn] the "user" directive makes sense only if the master process runs with super-user privileges, ignored in /etc/nginx/nginx.conf:2
2020/04/26 16:23:07 [emerg] 1#1: bind() to 0.0.0.0:80 failed (13: Permission denied)
nginx: [emerg] bind() to 0.0.0.0:80 failed (13: Permission denied)

```

From previous [section](./0-capabilities-bis-part4-psp-overrides-uid-capabilities.md#With-non-root-user).
We can see it could be interesting to also change the user to not be root, in case the psp does not define a range but the`rule: 'MustRunAsNonRoot'`

This is similar to pipenv (change finer level with group osef).

Note I edited the dropall capa, still this binding error but out of scope.
I assume pod run with psp at creation time and additivity. But did not check ok. 