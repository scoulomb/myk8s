# Volumes without external provider (Azure, AWS...)

## Global

- Use `EmptyDir`:https://kubernetes.io/docs/concepts/storage/volumes/#emptydir if not persitency neededed.
- If to read a git repo use `GitRepo`: https://kubernetes.io/docs/concepts/storage/volumes/#gitrepo or Empty Dir with init container which will read repo content
- If persitency on a node use
	- `HostPath`https://kubernetes.io/docs/concepts/storage/volumes/#hostpath (work on single node environment and not production friendly)
	- `Local` Use https://kubernetes.io/docs/concepts/storage/volumes/#local and node affinity (best++)
	
- Or `NFS` and deploy NFS server: https://kubernetes.io/docs/concepts/storage/volumes/#nfs (could use [QNAP NAS](https://github.com/scoulomb/misc-notes/blob/master/NAS-setup/README.md))


Note that `Local` volume unlike `HostPath` requires a pvc,
See [volume questions](./volume4question.md#1-emptydir-and-pvc).

<!-- ok clear -->
<!-- when using docker in local close to hostpath/local -->
<!-- OK -->

## Kubernetes distribution choice impact

Based on the choice of your Kubernetes distribution: 
See 
- https://github.com/scoulomb/misc-notes/blob/master/lab-env/README.md#kubernetes-distribution-alternative,
- https://github.com/scoulomb/misc-notes/blob/master/lab-env/README.md#other-methods
- https://github.com/scoulomb/misc-notes/blob/master/lab-env/README.md#related-links

Some impact are possible for `Local` and `HostPath` volume.

For example usage of k3d with HostPath requires a mapping:
From https://stackoverflow.com/questions/71475976/kubernetes-k3d-how-to-use-local-directory-as-a-persistent-volume

````
k3d cluster create NAME -v [SOURCE:]DEST[@NODEFILTER[;NODEFILTER...]]
````

It is similar when using Minikube with VM driver.
From https://stackoverflow.com/questions/48534980/mount-local-directory-into-pod-in-minikube

````
minikube start --mount-string="$HOME/go/src/github.com/nginx:/data" --mount
````

See also https://minikube.sigs.k8s.io/docs/handbook/mount/

From minikube doc, it seems docker dirver does not require the mount.

Stackoverflow [71475976] was also referring this link: https://web.archive.org/web/20220714203759/https://dev.to/bbende/k3s-on-raspberry-pi-volumes-and-storage-1om5,
It shows k3s local volume support and also longhorn support. Why longhorn?
> K3s comes with a default Local Path Provisioner that allows creating a PersistentVolumeClaim backed by host-based storage. This means the volume is using storage on the host where the pod is located.
> We get out-of-the-box support for persistent storage with K3s, but what if our pod goes down and is relaunched on a different node?
> In that case, the new node won’t have access to the data from /var/lib/rancher/k3s/storage on the previous node. To handle that case, we need distributed block storage.
> With distributed block storage, the storage is decouple from the pods, and the PersistentVolumeClaim can be mounted to the pod regardless of where the pod is running.
> Longhorn is a “lightweight, reliable and easy-to-use distributed block storage system for Kubernetes.” It is also created by Rancher Labs, so it makes the integration with K3s very easy.


Here I was using Kubeadm and not minikube: https://github.com/scoulomb/myk8s/blob/master/Volumes/fluentd-tutorial.md#step-2-adding-a-persistent-volume.
Reason why we did not face volume issue, using k3s also solves it. <!-- what was done for Antibes tri -->

When we perform volume mapping the HostPath, Local refers to mountpoint define in volume mapping, otherwise it is host one. 


## Deploy database on Kubernetes or host

If we have a database a better choice is to store it in bare metal and not use volume.
<!-- what was done for antibes tri -->

Use external service to target the database (public ip of the machine).
https://docs.openshift.com/dedicated/3/dev_guide/integrating_external_services.html.

<!-- 127.0.0.1 may not work if ingress run in docker, similar issue in https://github.com/open-denon-heos/remote-control#default-setup-explanation-in-docker, similar to nas public ip or private ip, when use public IP NAT rules applies even if in box WIFI, only exception is public ip on port 80 when in box WIFI, it routes 192.169.1.1, if NAT rule with port 80 in source is not defined, tested OK -->


See also best practise on this choice here:https://cloud.google.com/blog/products/databases/to-run-or-not-to-run-a-database-on-kubernetes-what-to-consider

## What about pictures/blob storage

- Use local volume (local file system) <!-- what was done for Antibes tri -->
- Store pictures in database, so come back to [above](#deploy-database-on-kubernetes-or-host) 
- We can deploy gluster fs and have a volume targetting glusterfs (not the volume itself here uses an external service!):
See https://kubernetes.io/fr/docs/concepts/storage/volumes/#glusterfs.

## Similar issue with Ingresses

Issue we faced with k3d and volume [mapping](#kubernetes-distribution-choice-impact) can be similar when using Ingress.

Here we need to define a port forwarding.
From : https://k3d.io/v5.0.0/usage/exposing_services/

````
k3d cluster create --api-port 6550 -p "8081:80@loadbalancer" --agents 2
````

It may also cause some issue with redirection (`80` -> `443`).
Note k3d doc disables it: `ingress.kubernetes.io/ssl-redirect: "false"` in ingress example.

By default it is activated: https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#server-side-https-enforcement-through-redirect

k3s makes it easier than k3d but still struggling in ingress setup (inp particular http to https redirect): 

https://stackoverflow.com/questions/68575472/k3s-redirect-http-to-https <!-- what was done for Antibes tri --> <!-- stop -->


It was easier when we deploy Traefik ingress controller here with Kubeadm distribution (https://github.com/scoulomb/misc-notes/blob/master/lab-env/kubernetes-distribution.md#kubeadm):
<!-- kubeadm because vagrant@k8sMaster -->
https://github.com/scoulomb/myk8s/blob/master/Services/service_deep_dive.md#deploy-the-traefik-controller

And here with mimikube with the Minikube redirection (https://github.com/scoulomb/misc-notes/blob/master/lab-env/kubernetes-distribution.md#minikube-docker-in-docker-and-local-multicluster)
- https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-i.md#details-on-http-and-https
- https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-h.md#extended-test

OpenShift, github page also offer similar redirection feature: https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-i.md#details-on-http-and-https

<!--
See details on OpenShift insecure edge termination policy at: private_script/blob/main/sei-auto/certificate/insecureEdgeTerminationPolicy-appendix.md
-->

<!-- Actually not was tragetting port 443 with http -->
