# Some questions I have on volume
 
## 1 emptyDir and pvc 

hostpath [here](./go-further.md#Can-I-use-hostPath-directly-without-pv-and-pvc-?)
is at same level as persistentVolumeClaim, emptyDir (would be true for nfs)

Note from [storage k8s doc](https://kubernetes.io/docs/concepts/storage/#types-of-volumes)

> Kubernetes supports several types of Volumes:
> configMap
> emptyDir
> hostPath
> nfs
> persistentVolumeClaim

Thus we can see that that pvc is considered as as volumes, But it is particular because it hides underlying storage of a pv.
So behind pvc we have nfs, hostpath

But pvc usage is only possible with persistent volumes
https://kubernetes.io/docs/concepts/storage/#persistentvolumeclaim
> A persistentVolumeClaim volume is used to mount a PersistentVolume into a Pod. PersistentVolumes are a way for users to “claim” durable storage (such as a GCE PersistentDisk or an iSCSI volume) without knowing the details of the particular cloud environment

https://kubernetes.io/docs/concepts/storage/persistent-volumes/#types-of-persistent-volumes
> GCEPersistentDisk
> AWSElasticBlockStore
> AzureDisk
> NFS
> HostPath (Single node testing only – local storage is not supported in any way and WILL NOT WORK in a multi-node cluster)

So not ConfigMap, emptyDir!

Emptydir keep storage only while pod is alive


## 2 Volume reclaim policy


Given: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#storage-object-in-use-protection
> If a user deletes a PVC in active use by a Pod, the PVC is not removed immediately. PVC removal is postponed until the PVC is no longer actively used by any Pods. Also, if an admin deletes a PV that is bound to a PVC, the PV is not removed immediately. PV removal is postponed until the PV is no longer bound to a PVC.

### pvc and pods

Thus if running l1-120 [of registry setup](./../Setup/ClusterSetup/LocalRegistrySetup/deploy-local-registry.sh)
````
vagrant@k8sMaster:~$ k delete pvc registry-claim
persistentvolumeclaim "registry-claim" deleted
^C
vagrant@k8sMaster:~$ k delete deployments.apps registry
deployment.apps "registry" deleted
vagrant@k8sMaster:~$ k delete pvc registry-claim
persistentvolumeclaim "registry-claim" deleted
````

We can see `pvc` removal is blocked.

### pv and pvc 

From [k8s pv doc](https://kubernetes.io/docs/concepts/storage/persistent-volumes#persistentvolumeclaims)
https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.17/#persistentvolumeclaim-v1-core
> What happens to a persistent volume when released from its claim. Valid options are Retain (default for manually created PersistentVolumes), Delete (default for dynamically provisioned PersistentVolumes), and Recycle (deprecated). Recycle must be supported by the volume plugin underlying this PersistentVolume. More info: https://kubernetes.io/docs/concepts/storage/persistent-volumes#reclaiming

Here [in registry setup](./../Setup/ClusterSetup/LocalRegistrySetup/deploy-local-registry.sh) in clean-up when we do 
`kubectl delete pvc registry-claim`.

Thus <deleting pvc before pv> should work, but sometime had to remove `kubernetes.io/pv-protection` when removing the volume.
(because probably rebound)

To simplify we could change when creating the volume [here](./../Setup/ClusterSetup/LocalRegistrySetup/deploy-local-registry.sh) 
````html
persistentVolumeReclaimPolicy: Retain
' > registryvol.yaml
````
 
The reclaim policy to deletion
And thus only have to delete the `pvc`.

Proof and experience

#### Test1: persistentVolumeReclaimPolicy: Reclaim policy = Retain and <delete the pv before pvc>

````
echo '
apiVersion: v1
kind: PersistentVolume
metadata:
  labels:
    type: local
  name: registryvol
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 200Mi
  hostPath:
    path: /tmp/registry
  persistentVolumeReclaimPolicy: Retain
' > registryvol.yaml

kubectl delete -f registryvol.yaml
kubectl apply -f registryvol.yaml

# This an extract from  creating registry yaml
echo '
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  creationTimestamp: null
  labels:
    service: registry-claim
  name: registry-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
status: {}
' > localregistry-pvc.yaml

k delete -f localregistry-pvc.yaml
k apply -f localregistry-pvc.yaml
````
Status is
````
vagrant@k8sMaster:~$ k get pvc | grep registry
registry-claim    Bound    registryvol        200Mi      RWO                           54s
vagrant@k8sMaster:~$
````

Now I will delete the pv 

````
kubectl delete -f registryvol.yaml
k delete -f localregistry-pvc.yaml
````
Volume will only be removed after I remove of finalizers doing `k edit pv registryvol`
Then nothing is present.

#### Test2: Same but removing pvc before pv

````
k get pvc | grep registry
k get pv | grep registry

k apply -f registryvol.yaml
k apply -f localregistry-pvc.yaml

k get pvc | grep registry
k get pv | grep registry

k delete -f localregistry-pvc.yaml

k get pvc | grep registry
k get pv | grep registry


kubectl delete -f registryvol.yaml

````

Output is:

````
vagrant@k8sMaster:~$ k get pvc | grep registry
vagrant@k8sMaster:~$ k get pv | grep registry
vagrant@k8sMaster:~$ k apply -f registryvol.yaml
persistentvolume/registryvol created
vagrant@k8sMaster:~$ k apply -f localregistry-pvc.yaml
persistentvolumeclaim/registry-claim created
vagrant@k8sMaster:~$ k get pvc | grep registry
registry-claim    Bound    registryvol        200Mi      RWO                           22s
vagrant@k8sMaster:~$ k get pv | grep registry
registryvol        200Mi      RWO            Retain           Bound    default/registry-claim
          31s
vagrant@k8sMaster:~$ k delete -f localregistry-pvc.yaml
persistentvolumeclaim "registry-claim" deleted
vagrant@k8sMaster:~$ k get pvc | grep registry
vagrant@k8sMaster:~$ k get pv | grep registry
registryvol        200Mi      RWO            Retain           Released   default/registry-claim
            69s
vagrant@k8sMaster:~$ kubectl delete -f registryvol.yaml
persistentvolume "registryvol" deleted
vagrant@k8sMaster:~$
````
No error but we had to delete the volume by hand because of retain policy.

## Test3: Same but using delete reclaim policy in pv

Edit  `registryvol.yaml` and change `persistentVolumeReclaimPolicy: Retain` to `persistentVolumeReclaimPolicy: Delete`
Run same test

Output is: 

````
vagrant@k8sMaster:~$ k get pvc | grep registry
vagrant@k8sMaster:~$ k get pv | grep registry
vagrant@k8sMaster:~$ k apply -f registryvol.yaml
persistentvolume/registryvol created
vagrant@k8sMaster:~$ k apply -f localregistry-pvc.yaml
persistentvolumeclaim/registry-claim created
vagrant@k8sMaster:~$ k get pvc | grep registry
registry-claim    Bound    registryvol        200Mi      RWO                           4s
vagrant@k8sMaster:~$ k get pv | grep registry
registryvol        200Mi      RWO            Delete           Bound    default/registry-claim
          14s
vagrant@k8sMaster:~$ k delete -f localregistry-pvc.yaml
persistentvolumeclaim "registry-claim" deleted
vagrant@k8sMaster:~$ k get pvc | grep registry
vagrant@k8sMaster:~$ k get pv | grep registry
vagrant@k8sMaster:~$ kubectl delete -f registryvol.yaml
Error from server (NotFound): error when deleting "registryvol.yaml": persistentvolumes "registryvol" not foundvagrant@k8sMaster:~$
````

I did not have to delete persistent volume manually it was done with the pvc

## 2 Storage class

### Storage class (manual)

We had seen [in fluentd tuto](https://github.com/scoulomb/myk8s/blob/1703abce0cfea091aa2016582b19dcc14eefd8ff/Volumes/fluentd-tutorial.md#step-2-adding-a-persistent-volume)
the use of `storageClassName: manual` to tigth a pvc and pc

### Dynamic provisionning

Rather than creating the volume by hand.
We could dynamically provision the volume. 
Because of that, the recycle reclaim policy seen above in persistentVolumeReclaimPolicy is deprecated.
Quoting the [doc](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#recycle):
> The Recycle reclaim policy is deprecated. Instead, the recommended approach is to use dynamic provisioning.

It not necessary to recycle a volume as it can be dynamically provisioned!

From k8s [dynamic provisioning doc](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/#enabling-dynamic-provisioning)

### IBM: Here is an example of nfs storage provisioning
https://developer.ibm.com/technologies/containers/tutorials/add-nfs-provisioner-to-icp/


NFS is located here: https://github.com/scoulomb/myk8s/blob/master/Volumes/go-further.md#can-i-use-hostpath-directly-ithout-pv-and-pvc
same place as host path 


### Test 

We had
Test1: persistentVolumeReclaimPolicy: Reclaim policy = Retain and <delete the pv before pvc>
If I change to:
Test1: persistentVolumeReclaimPolicy: Retain and <not delete the pv, but delete pvc using dynamic provisioning>
I expect a new pv, and old pv kept! [NOT TESTED and will not :)]


## 4 ConfigMap consumption

`ConfigMap` (also `secret`) can be consumed as:

- Pod environment variable
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#define-container-environment-variables-using-configmap-data
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#define-container-environment-variables-with-data-from-multiple-configmaps
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables

- Use configmap values in pod command (special case of env var)
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#configure-all-key-value-pairs-in-a-configmap-as-container-environment-variables

- Populate volume from ConfigMap
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#populate-a-volume-with-data-stored-in-a-configmap
Fluentd conf: https://github.com/scoulomb/myk8s/blob/master/Volumes/fluentd-tutorial.md#step-3-adding-fluentd-for-logger-configuration
https://github.com/scoulomb/myk8s/blob/master/Volumes/fluentd-tutorial.md#general and https://github.com/scoulomb/myk8s/blob/master/Volumes/go-further.md

- Add ConfigMap data to a specific path in a volume 
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#add-configmap-data-to-a-specific-path-in-the-volume
Here we select a specif cm key

- Set file names and access mode in Volume form ConfigMap data (particular case)
https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#project-keys-to-specific-paths-and-file-permissions

- Can be used by system components and controller (k8s controller)
https://clouddocs.f5.com/products/connectors/k8s-bigip-ctlr/v1.5/#f5-resource-configmap-properties


Volume ccl ok