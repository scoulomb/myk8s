# Setup admission controller plugin

## Why ?

I created Pod Security Policy (PSP) but it was not taken into account.
To have it effective we need to enable the PSP admission controller.

When PSP are activated by default an user can perform nothing 

- Except if explicitly allowed -> cf k8s book / Security chapter (bob and alice)
- Same apply for service account -> cf. [kubernetes.io](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#example). Where we allow resource but policy applied.
- Except root -> cf. [kubernetes.io](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#example).


## API server

It seems easy 

- https://kubernetes.io/docs/concepts/policy/pod-security-policy/#enabling-pod-security-policies
- https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#how-do-i-turn-on-an-admission-controller
- https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/-> search PodSecurityPolicy

## But I am using kubeadm 

https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/control-plane-flags/

## Setup minikube with Admission Controller plugin

Unfortunately I was not able to setup the admission controller using Kubeadm
Thus I will setup minikube where it is easier to setup admission conroller.

I will install minikube on with none option for VM.
Note VirtualBox is not a compatible driver for Ubuntu.

Procedure for setup can be found in this [link](https://kubernetes.io/docs/tasks/tools/install-minikube/#install-minikube-via-direct-download),
The VM setup readme can be found [here](../Setup/MinikubeSetup/README.md).
We could install it on Ubuntu bare metal (but my Ubuntu PC died)

Then I have to be root so let's do:

```buildoutcfg
sudo -s
```

Install docker in case it failed

````buildoutcfg
sudo apt-get update
sudo apt-get install -y docker.io
````

I will start minikube and enable the admission controller plugin as described [here](https://livebook.manning.com/book/kubernetes-in-action/chapter-13/156) when using Minikube.

-> this will create 2 non service account user; if needed to be used
```buildoutcfg
cat <<EOF | minikube ssh sudo tee /etc/kubernetes/passwd
password,alice,1000,basic-user
password,bob,2000,privileged-user
EOF

```

Become for none driver for which ssh is not needed

```buildoutcfg
mkdir /etc/kubernetes
cat <<EOF | tee /etc/kubernetes/passwd
password,alice,1000,basic-user
password,bob,2000,privileged-user
EOF
```

Then I will start minikube and activate admission controller.

````buildoutcfg
minikube start --driver=none --extra-config apiserver.Authentication.PasswordFile.BasicAuthFile=/etc/kubernetes/passwd --extra-config=apiserver.Authorization.Mode=RBAC --extra-config=apiserver.GenericServerRunOptions.AdmissionControl=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds,PodSecurityPolicy
````
=> Not successful 

I had to remove `Authentication.PasswordFile.BasicAuthFile`

````buildoutcfg
minikube start --driver=none --extra-config=apiserver.Authorization.Mode=RBAC --extra-config=apiserver.GenericServerRunOptions.AdmissionControl=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds,PodSecurityPolicy
````
=> Not successful 

We can use `minikube logs -f` for debugging.
In logs


````buildoutcfg
"kube-apiserver-minikube_kube-system(23cdb6e95224cdcb4a0895d61f0a13b2)"), skipping: failed to "StartContainer" for "kube-apiserver" with CrashLoopBackOff: "back-off 1m20s restarting failed container=kube-apiserver pod=kube-apiserver-minikube_kube-system(23cdb6e95224cdcb4a0895d61f0a13b2)"
❌  Problems detected in kube-apiserver [7a384b4d250a]:
    Error: unknown flag: --Authorization.Mode
````


````buildoutcfg
minikube start --driver=none 
````
=> Successful but no psp.

So tried

````buildoutcfg
minikube start --driver=none --extra-config=apiserver.GenericServerRunOptions.AdmissionControl=PodSecurityPolicy
````

Then error: `Error: unknown flag: --GenericServerRunOptions.AdmissionControl`

From here: https://github.com/kubernetes/minikube/issues/3524

We should use

> minikube start --extra-config=apiserver.enable-admission-plugins="Initializers,NamespaceLifecycle...

So using this new key and also all options (otherwise not working)

````buildoutcfg
minikube start --driver=none --extra-config=apiserver.enable-admission-plugins="NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds,PodSecurityPolicy"
````
=> In logs can see already better but 

````buildoutcfg
I0425 16:26:24.036955       1 event.go:278] Event(v1.ObjectReference{Kind:"DaemonSet", Namespace:"kube-system", Name:"kube-proxy", UID:"8968300d-9122-4bee-9e33-21c58effc819", APIVersion:"apps/v1", ResourceVersion:"241", FieldPath:""}): type: 'Warning' reason: 'FailedCreate' Error creating: pods "kube-proxy-" is forbidden: no providers available to validate pod request
````

Most likely because of pod security policy so trick is normal start without admission controller 
and add them after

FINAL SOLUTION:L

````buildoutcfg
minikube delete
minikube start --driver=none 
minikube start --driver=none --extra-config=apiserver.enable-admission-plugins="NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds,PodSecurityPolicy"
````


And this is finally working :).

````buildoutcfg
root@minikube:~# kubectl get pods --all-namespaces
NAMESPACE     NAME                               READY   STATUS              RESTARTS   AGE
kube-system   coredns-66bff467f8-dkb2g           0/1     ContainerCreating   0          39s
kube-system   coredns-66bff467f8-qgb2j           0/1     ContainerCreating   0          39s
kube-system   etcd-minikube                      1/1     Running             0          38s
kube-system   kube-apiserver-minikube            1/1     Terminating         0          38s
kube-system   kube-controller-manager-minikube   1/1     Running             0          38s
kube-system   kube-proxy-jhr7q                   1/1     Running             0          39s
kube-system   kube-scheduler-minikube            1/1     Running             0          38s
kube-system   storage-provisioner                1/1     Running             0          41s
````

So options in k8s in action book are not accurate.

And for auto-completion with root do `/vagrant/setupBash.sh; source ~/.bashrc`.

We will now follow this procedure in next [section](0-capabilities-bis-part3-psp-tutorial.md)