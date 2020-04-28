# Tutorial to setup Fluentd for logging: leverage volume and composite containers


## Prerequisite

- Start up k8s VM with vagrant
- ./restart.sh to restart kube
- repdeloy-registry is not needed here :)

## Objective

We will show how to deploy a multi-container pods.
Here we will deploy
- 1 nginx container
- 1 fluentd container which will display nginx logs

This is an implementation of adapter container:
- [adapter container](https://books.google.de/books?id=5hJNDwAAQBAJ&pg=PA35&lpg=PA35&dq=fluentd+adapter+container&source=bl&ots=0sF0yTFgqe&sig=ACfU3U1dBjFiB0qzE9uURtRJ6QcbeYg9NA&hl=fr&sa=X&ved=2ahUKEwjLnNH3xdHnAhXJYcAKHTmxDdoQ6AEwAnoECAkQAQ#v=onepage&q=fluentd%20adapter%20container&f=false).
- [k8s blog](https://kubernetes.io/blog/2015/06/the-distributed-system-toolkit-patterns/)

It could be also seen as an ambassador.

This will show:
- `ConfigMap`/ `Secret` consumed as volume
- `pv` and `pvc`
- `Hostpath` `pv` type
- `Multicontainers` pod sharing same `pv`

## Step 1: two container and no persistent volume

```yaml
k create deployment basic --image=nginx --dry-run -o yaml > basic.yaml

# Edit

echo '
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: basic
  name: basic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: basic
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: basic
    spec:
      containers:
      - image: nginx
        name: nginx
        ports:
        - containerPort: 80
      - image: fluent/fluentd
        name: fdlogger
' > basic.yaml

k delete -f basic.yaml
k create -f basic.yaml

```
Open second window and do

```` shell script
export POD_IP=$(k get pods -o wide | grep "basic-" |  awk '{ print $6 }')
watch curl $POD_IP
````

Then in previous window do

````shell script
export POD_NAME=$(k get pods -o wide | grep "basic-" |  awk '{ print $1 }')
export POD_IP=$(k get pods -o wide | grep "basic-" |  awk '{ print $6 }')
echo $POD_NAME
echo $POD_IP

k exec -c nginx -it $POD_NAME -- /bin/bash
ls -l /var/log/nginx/access.log
tail -f  /var/log/nginx/access.log
exit
````

tails returns nothing however

````shell script
basic-586b499858-jmxlg:/# ls -l /var/log/nginx/access.log
lrwxrwxrwx 1 root root 11 Feb  2 08:06 /var/log/nginx/access.log -> /dev/stdout
````

We see it is redirected to stdout so that doing:

````shell script
vagrant@k8sMaster:~$ k logs basic-586b499858-jmxlg -c nginx
10.0.2.15 - - [14/Feb/2020:21:10:05 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [14/Feb/2020:21:10:07 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [14/Feb/2020:21:10:09 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"

````
returns logs!


## Step 2: Adding a persistent volume

For this we will  create a `pv` and `pvc`.
````yaml
echo '
kind: PersistentVolume
apiVersion: v1
metadata:
  name: weblog-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 100Mi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/tmp/weblog"
' >  weblog-pv.yaml

echo '
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: weblog-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
' > weblog-pvc.yaml

k delete -f weblog-pv.yaml
# if not deleted edit: k edit weblog-pv-volume and remove finalizers
k delete -f weblog-pvc.yaml
k create -f weblog-pv.yaml
k create -f weblog-pvc.yaml

````

Be careful path must be absolute!! in host path
If you need to to delete the volume, and this does not work do:
`k edit volume <volume-name>`

and remove follwing lines:
````yaml
finalizers:
  -  kubernetes.io/pv-protection
````
Source:
- https://stackoverflow.com/questions/46526165/docker-invalid-characters-for-volume
- https://medium.com/@miyurz/kubernetes-deleting-resource-like-pv-with-force-and-grace-period-0-still-keeps-pvs-in-3f4ad8710e51


Then modify `basic.yaml` to declare volume in the pod and mount it in the two containers

````yaml
k delete -f basic.yaml
echo '
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: basic
  name: basic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: basic
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: basic
    spec:
      volumes:
      - name: weblog-pv-storage
        persistentVolumeClaim:
          claimName: weblog-pv-claim
      containers:
      - image: nginx
        name: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: "/var/log/nginx"
          name: weblog-pv-storage
      - image: fluent/fluentd
        name: fdlogger
        volumeMounts:
        - mountPath: "/var/log"
          name: weblog-pv-storage
' > basic2.yaml

diff basic.yaml basic2.yaml
k create -f basic2.yaml
````

Note use a deployment here but we could declare a pod directly instead.

!! Warning: mountpath is an absolute path

Open second window and do

```` shell script
export POD_IP=$(k get pods -o wide | grep "basic-" |  awk '{ print $6 }')
watch curl $POD_IP
````

Then in previous window do

```` shell script
export POD_NAME=$(k get pods -o wide | grep "basic-" |  awk '{ print $1 }')
export POD_IP=$(k get pods -o wide | grep "basic-" |  awk '{ print $6 }')
echo $POD_NAME
echo $POD_IP

k exec -c nginx -it $POD_NAME -- /bin/bash
 ls -all /var/log/nginx/access.log
tail -f  /var/log/nginx/access.log
exit

````

So that tail output is

````shell script
vagrant@k8sMaster:~$ k exec -c nginx -it $POD_NAME -- /bin/bash
root@basic-567b94d5f-6nml8:/# tail -f  /var/log/nginx/access.log
10.0.2.15 - - [12/Feb/2020:18:22:14 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [12/Feb/2020:18:37:06 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [12/Feb/2020:18:37:07 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
````

Note the fact we have volume does not redirect to stdout:

````shell script
root@basic-6d8dbc8798-v2n4q:/# ls -all /var/log/nginx/access.log
-rw-r--r-- 1 root root 20340 Feb 14 21:21 /var/log/nginx/access.log
````

This is why if we do `k logs -f  $POD_NAME nginx`, logs are not returned
````shell script
vagrant@k8sMaster:~$ k logs -f  $POD_NAME nginx
^C
vagrant@k8sMaster:~$ k logs -f  $POD_NAME fdlogger
2020-02-13 09:27:14 +0000 [info]: parsing config file is succeeded path="/fluentd/etc/fluent.conf"
````

Nothing we will now configure fluentd correctly to read correct configuration.
`/fluentd/etc/fluent.conf` is the default configuration.

From: https://docs.fluentd.org/configuration/config-file#docker
> If you're using the Docker container, the default location is located at /fluentd/etc/fluent.conf

### Step 3: Adding fluentd for logger configuration

We will write fluent configuration, in a ConfigMap.

```` yaml
echo '
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluentd.conf: |
    <source>
      @type tail
      format none
      path /var/log/access.log
      tag count.format1
    </source>

    <match *.**>
      @type stdout
    </match>' > weblog-configmap.yaml

k delete -f weblog-configmap.yaml
k create -f weblog-configmap.yaml

````

This line `path /var/log/access.log` request fluentd to look for logs at this location.
This location is the `$mountpoint/access.log` of shared volume, where nginx logs.

We modify deployment as follows, to mount consume the ConfigMap as a volume.
And specify in container `commands` and `args` to look for the configuration where the ConfigMap is mounted.

```` yaml
k delete -f basic2.yaml
echo '
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: basic
  name: basic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: basic
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: basic
    spec:
      volumes:
      - name: weblog-pv-storage
        persistentVolumeClaim:
          claimName: weblog-pv-claim
      - name: log-config
        configMap:
          name: fluentd-config
      containers:
      - image: nginx
        name: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: "/var/log/nginx"
          name: weblog-pv-storage
      - image: fluent/fluentd
        command: ["fluentd"]
        args: ["-c", "/etc/fluentd-config/fluentd.conf", "--verbose"]
        name: fdlogger
        volumeMounts:
        - mountPath: "/var/log"
          name: weblog-pv-storage
        - mountPath: "/etc/fluentd-config"
          name: log-config
' > basic3.yaml
diff basic2.yaml basic3.yaml
k create -f basic3.yaml
````

Then in a separate window do:

````shell script
export POD_IP=$(k get pods -o wide | grep "basic-" |  awk '{ print $6 }')
echo $POD_IP
watch -n1 curl $POD_IP
````


Then we can tail the logs
````shell script
export POD_NAME=$(k get pods -o wide | grep "basic-" |  awk '{ print $1 }')
k logs -f $POD_NAME fdlogger
````

Logs appears:

````shell script
2020-02-14 21:35:56.771414998 +0000 count.format1: {"message":"10.0.2.15 - - [14/Feb/2020:21:35:56 +0000] \"GET / HTTP/1.1\" 200 612 \"-\" \"curl/7.58.0\" \"-\""}
2020-02-14 21:35:57.769463739 +0000 count.format1: {"message":"10.0.2.15 - - [14/Feb/2020:21:35:57 +0000] \"GET / HTTP/1.1\" 200 612 \"-\" \"curl/7.58.0\" \"-\""}
````

We can also see that fluentd is correctly configured by doing

````shell script
vagrant@k8sMaster:~$ k logs $POD_NAME fdlogger | grep "parsing config file is succeeded path="
2020-02-14 21:31:17 +0000 [info]: fluent/log.rb:322:info: parsing config file is succeeded path="/etc/fluentd-config/fluentd.conf"
vagrant@k8sMaster:~$ k logs $POD_NAME fdlogger | grep access
    path "/var/log/access.log"
2020-02-14 21:31:18 +0000 [info]: #0 fluent/log.rb:322:info: following tail of /var/log/access.log
vagrant@k8sMaster:~$
````


## Explanations and wrap-up

### General

````html
- `ConfigMap`/`Secret`                <- `pod template`:  `spec.volumes` <- `pod template`: `spec.containers.volumeMounts`
- `hostPath volume` <- `pv` <- `pvc`  <- `pod template`:  `spec.volumes` <- `pod template`: `spec.containers.volumeMounts`
````

We show an example of secret consumption as a volume [here](./../Security/1-secret-creation-consumption.md).

A `configMap`/`Secret` can also be consumed as environment variable.

Sometime we consume `ConfigMap`/`Secret` as a volume and have an environment variable which is pointing to that volume.
Note that when we consume a `ConfigMap`/`Secret` has en environment var, if `ConfigMap`/`Secret` is updated. This wil need the pod to restart to be updated.
Unlike volume. However there is a sync delay as explained in the [doc](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#mounted-configmaps-are-updated-automatically).

We summarize other usage of `configMap`/`Secret` in this [question](./volume4question.md#4.-ConfigMap-consumption)

### In the example
We have a single hostPath `pv`, declared in pod template and mounted in nginx and fluentd containers

So that logs are populated by nginx in`mountPath: "/var/log/nginx"` (pv)
and since same volume is mounted in fluentd in `mountPath: "var/log"` (pv)

Logs are visible by fluentd in `/var/log/access.log` (and not `/var/log/nginx/access.log`, and it makes sense because of mountpoint)

Then we have a ConfigMap containing fluentd conf, consumed as a volume and mounted in fluentd container
(NO ENV VAR: fluentd container has an env var pointing to `mountpoint of that volume/cm key name` containing fluentd conf (FLUENTD_ARGS, value: -c /etc/fluentd-config/fluentd.conf)
-- REPLACED BY:) fluentd container when start has an argument pointing to `mountpoint of that volume/cm key name` containing fluentd conf (/etc/fluentd-config/fluentd.conf)

The fluentd conf points to log file in `/var/log/access.log` (and not `/var/log/nginx/access.log`)

So that fluentd container will look for it configuration in a file located at location given at container start (/etc/fluentd-config/fluentd.conf)
This config file will point to  `/var/log/access.log`  (and not `/var/log/nginx/access.log`) which contains nginx logs!
and will display in stdout of fluentd container.

So that we can do `k logs -f $POD_NAME fdlogger` (as forwarding is correctly set!) and see nginx logs from fluentd container with potential processing

We can also see the log in hostpath directly:

````shell script
 hostPath:
  path: "/tmp/weblog"

vagrant@k8sMaster:~$ cat /tmp/weblog/access.log
10.0.2.15 - - [14/Feb/2020:21:37:25 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [14/Feb/2020:21:37:26 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [14/Feb/2020:21:37:27 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
````
From there we can understand that we mount `/tmp/weblog/` at `/var/log/nginx` and `var/log`m, thus the different location in the 2 containers!

[Next steps](./go-further.md)

## Docs
- https://github.com/fluent/fluentd
- https://stackoverflow.com/questions/20559255/error-while-installing-json-gem-mkmf-rb-cant-find-header-files-for-ruby
- https://github.com/kubernetes/community/blob/master/contributors/design-proposals/storage/persistent-storage.md
- [lfd259 forum questions](https://forum.linuxfoundation.org/discussion/856545/lab-5-3-with-fluentd-is-too-confusing#latest)