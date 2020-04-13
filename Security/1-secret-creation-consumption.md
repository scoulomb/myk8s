# Secret creation and consumption as volume

## Base 64

````
vagrant@k8sMaster:~/tutu
$ echo p@ssw3od | base64
cEBzc3czb2QK

````

## Create secret

````
echo '
apiVersion: v1
kind: Secret
metadata:
   name: database-secret
data:
   password: cEBzc3czb2QK' > database-secret.yaml

k create -f database-secret.yaml
````

## Then create a pod which consumes the secret as volume [FINAL STEP]

This was detailled here: https://github.com/scoulomb/myk8s/blob/master/Volumes/fluentd-tutorial.md#general


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
    volumeMounts:
    - name: mariadb
      mountPath: /mariadb-password
  volumes:
  - name: mariadb
    secret:
      secretName: database-secret
' > app.yaml

k delete -f app.yaml
k create -f app.yaml
````

## Read the secret

````
$ k get pods
NAME                        READY   STATUS    RESTARTS   AGE
app                         1/1     Running   0          32s

$ k get pods
NAME                        READY   STATUS    RESTARTS   AGE
app                         1/1     Running   0          32s
registry-55c5877699-gp5tt   1/1     Running   1          2d16h
vagrant@k8sMaster:~/tutu
$ k exec -it app -- /bin/sh
/ $ cat /mariadb-password/password
p@ssw3od
/ $ cd mariadb-password/
/mariadb-password $ ls -al
total 4
drwxrwxrwt    3 root     root           100 Apr 11 09:28 .
drwxr-xr-x    1 root     root          4096 Apr 11 09:29 ..
drwxr-xr-x    2 root     root            60 Apr 11 09:28 ..2020_04_11_09_28_45.845423307
lrwxrwxrwx    1 root     root            31 Apr 11 09:28 ..data -> ..2020_04_11_09_28_45.845423307
lrwxrwxrwx    1 root     root            15 Apr 11 09:28 password -> ..data/password
/mariadb-password $ cat password
p@ssw3od
/mariadb-password $ cat ..data/password
p@ssw3od
/mariadb-password $ cat ..2020_04_11_09_28_45.845423307/password
p@ssw3od
````