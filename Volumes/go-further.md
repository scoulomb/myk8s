# Questions

## Volumes and several replicas

Starting from step 3 in [fluentd-tutorial](./fluentd-tutorial.md).

We will now scale the number of replicas to 3 using `k scale --replicas=3 deployment/basic`.

````shell script
vagrant@k8sMaster:~$ k get pods -o wide
NAME                     READY   STATUS    RESTARTS   AGE     IP               NODE        NOMINATED NODE   READINESS GATES
basic-56d576679d-hm6kz   2/2     Running   0          3m18s   192.168.16.169   k8smaster   <none>           <none>
basic-56d576679d-st796   2/2     Running   0          3m18s   192.168.16.159   k8smaster   <none>           <none>
basic-56d576679d-v9vh8   2/2     Running   0          7m7s    192.168.16.183   k8smaster   <none>           <none>
vagrant@k8sMaster:~$
````
Then we can tail the logs
````shell script
export POD_NAME_1=$(k get pods -o wide | grep "basic-" |  sed -n 1p | awk '{ print $1 }')
echo $POD_NAME_1
k logs -f $POD_NAME_1 -c fdlogger
````
We see no logs (note `-c` optional, set `k logs -f $POD_NAME_1 fdlogger` is working)


Then in a separate window do:

````shell script
export POD_IP_3=$(k get pods -o wide | grep "basic-" | sed -n 3p |  awk '{ print $6 }')
echo $POD_IP_3
watch -n1 curl $POD_IP_3
````

We can see logs appear because it is targeting the same persistent volume !
This should be in general the case with persistent volumes (cf. nfs which reference a server name).
(not empty dir and confirmed by comment below)

## Several replicas and several nodes

However hostpath is particular because volume is on the host.
If we have `>1` in the cluster and using host path, we would see only logs from pods deployed in the same node.

This `Hostpath` volume behavior is confirmed here in [k8s blog](https://kubernetes.io/blog/2019/04/04/kubernetes-1.14-local-persistent-volumes-ga/).

They introduced `Local persistent volume` to have pods deployed on a node where volume is located.
So that if pods is redeployed/needs data in the volume, it will be always on the node having the volume.
Preventing data loss.

Quoting k8s blog:
> To better understand the benefits of a Local Persistent Volume, it is useful to compare it to a HostPath volume. HostPath volumes mount a file or directory from the host node’s filesystem into a Pod. Similarly a Local Persistent Volume mounts a local disk or partition into a Pod.
> The biggest difference is that the Kubernetes scheduler understands which node a Local Persistent Volume belongs to. With HostPath volumes, a pod referencing a HostPath volume may be moved by the scheduler to a different node resulting in data loss. But with Local Persistent Volumes, the Kubernetes scheduler ensures that a pod using a Local Persistent Volume is always scheduled to the same node.
> While HostPath volumes may be referenced via a Persistent Volume Claim (PVC) or directly inline in a pod definition, Local Persistent Volumes can only be referenced via a PVC. This provides additional security benefits since Persistent Volume objects are managed by the administrator, preventing Pods from being able to access any path on the host.

So it confirms we can use HostPath in several nodes but it is not supported as per [k8s doc](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/#create-a-persistentvolume)

> In a production cluster, you would not use hostPath. Instead a cluster administrator would provision a network resource like a Google Compute Engine persistent disk, an NFS share, or an Amazon Elastic Block Store volume. Cluster administrators can also use StorageClasses to set up dynamic provisioning.

And in this [ServerFault question](https://serverfault.com/questions/850472/why-are-kubernetes-hostpath-volumes-single-node-only).

This is also mentioned in k8s book (`6.3.1. Introducing the hostPath volume`) 

## Can I use hostPath directly without pv and pvc ?

Here [in fluend tuto](fluentd-tutorial.md#step-2-adding-a-persistent-volume) we had used a `pvc` but could directly use a `pv`.

```` yaml
k delete -f hostpath-direct-test.yaml
echo '
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: hostpath-direct-test
  name: hostpath-direct-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hostpath-direct-test
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: hostpath-direct-test
    spec:
      volumes:
      - name: hostpath-direct-test-vol
        hostPath:
          path: "/tmp/hostpath-direct-test"
      containers:
      - image: nginx
        name: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - mountPath: "/var/log/nginx"
          name: hostpath-direct-test-vol
' > hostpath-direct-test.yaml

k create -f hostpath-direct-test.yaml

tail -f /tmp/hostpath-direct-test/access.log
````

Then in a separate window do:

````shell script
export POD_IP=$(k get pods -o wide | grep "hostpath-direct-test-" | sed -n 1p |  awk '{ print $6 }')
watch curl $POD_IP
````

Tail start outputting

````shell script
grant@k8sMaster:~$ tail -f /tmp/hostpath-direct-test/access.log
10.0.2.15 - - [15/Feb/2020:14:47:13 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [15/Feb/2020:14:47:15 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [15/Feb/2020:14:47:17 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [15/Feb/2020:14:47:19 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
10.0.2.15 - - [15/Feb/2020:14:47:21 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.58.0" "-"
````

Not using `pv` and `pvc` is not not possible for all kinds of volumes.
Cf. [local persistent volume](https://kubernetes.io/blog/2019/04/04/kubernetes-1.14-local-persistent-volumes-ga/) discussed above

> While HostPath volumes may be referenced via a Persistent Volume Claim (PVC) or directly inline in a pod definition, Local Persistent Volumes can only be referenced via a PVC.

So here we had
````html
- `ConfigMap`/`Secret`                <- `pod template`:  `spec.volumes` <- `pod template`: `spec.containers.volumeMounts`
- `hostPath volume` <- `pv` <- `pvc`  <- `pod template`:  `spec.volumes` <- `pod template`: `spec.containers.volumeMounts`
````
We now have
````html
- `hostPath volume`                   <- `pod template`  spec.volumes` <- `pod template` `spec.containers.volumeMounts`
````

In this [question](./volume4question.md#1.-emptyDir-and-pvc), we give more details.

This is consistent with k8s book (`figure 6.8`).
where hostPath can be replaced by  a gcePersistentDisk (or nfs).
In `Figure 6.7` they say:
> PersistentVolumes, like cluster Nodes, don’t belong to any namespace, unlike pods and PersistentVolumeClaims.`

But when using hostPath note, we reattach to a Node!

In k8s book they took a reverse approach (simple to complex vs synthetic).

[Next steps](./volume4question.md)