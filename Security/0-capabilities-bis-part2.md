# Setup minikube with Admission Controller plugin

Unfortunately I was not able to setup the admission controller using Kubeadm
Thus I will setup minikube where it is easier to setup admission conroller.

I will install minikube on Ubuntu Bionic bare metal with none option for VM.
Note VirtualBox is not a compatible driver for Ubuntu.


Procedure for setup can be found in this [link](https://kubernetes.io/docs/tasks/tools/install-minikube/#install-minikube-via-direct-download),

````buildoutcfg
sudo minikube start --driver=none
````


Then I have to be root so let's do:

```buildoutcfg
sudo -s
```


I will now enable the admission controller plugin as described [here](https://livebook.manning.com/book/kubernetes-in-action/chapter-13/156) when using Minikube.

-> this will create 2 non service account user; if needed to be used
```buildoutcfg
cat <<EOF | minikube ssh sudo tee /etc/kubernetes/passwd
password,alice,1000,basic-user
password,bob,2000,privileged-user
EOF

```

Become for none driver for which ssh is not needed

```buildoutcfg
cat <<EOF | sudo tee /etc/kubernetes/passwd
password,alice,1000,basic-user
password,bob,2000,privileged-user
EOF

```


Then 

````buildoutcfg
minikube start --extra-config apiserver.Authentication.PasswordFile.BasicAuthFile=/etc/kubernetes/passwd --extra-config=apiserver.Authorization.Mode=RBAC --extra-config=apiserver.GenericServerRunOptions.AdmissionControl=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds,PodSecurityPolicy
````


# Ready to perform the tutorial

We will now follow this tutorial from [kubernetes.io](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#example).

Since we have a cluster with the PodSecurityPolicy admission controller enabled and have cluster admin privileges.

## Set up

Set up a namespace and a service account to act as for this example. We’ll use this service account to mock a non-admin user.

```buildoutcfg
kubectl create namespace psp-example
kubectl create serviceaccount -n psp-example fake-user
kubectl create rolebinding -n psp-example fake-editor --clusterrole=edit --serviceaccount=psp-example:fake-user
```

To make it clear which user we’re acting as and save some typing, create 2 aliases:

````buildoutcfg
alias kubectl-admin='kubectl -n psp-example'
alias kubectl-user='kubectl --as=system:serviceaccount:psp-example:fake-user -n psp-example'
````

Create a policy and a pod

Define the example PodSecurityPolicy object in a file. This is a policy that simply prevents the creation of privileged pods. The name of a PodSecurityPolicy object must be a valid DNS subdomain name.

```buildoutcfg
vi example-psp.yaml 

apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: example
spec:
  privileged: false  # Don't allow privileged pods!
  # The rest fills in some required fields.
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
  - '*'
```
# And create it with kubectl:

```buildoutcfg
kubectl-admin create -f example-psp.yaml
```

Now, as the unprivileged user, try to create a simple pod:

```buildoutcfg
kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
```


Error from server (Forbidden): error when creating "STDIN": pods "pause" is forbidden: unable to validate against any pod security policy: []

What happened? Although the PodSecurityPolicy was created, neither the pod’s service account nor fake-user have permission to use the new policy:

kubectl-user auth can-i use podsecuritypolicy/example
no

Create the rolebinding to grant fake-user the use verb on the example policy:

    Note: This is not the recommended way! See the next section for the preferred approach.

kubectl-admin create role psp:unprivileged \
    --verb=use \
    --resource=podsecuritypolicy.policy \
    --resource-name=example
    
# kubectl-admin create role psp:unprivileged     --verb=use     --resource=podsecuritypolicies.extensions   --resource-name=example
role.rbac.authorization.k8s.io/psp:unprivileged created

        
role "psp:unprivileged" created

kubectl-admin create rolebinding fake-user:psp:unprivileged \
    --role=psp:unprivileged \
    --serviceaccount=psp-example:fake-user-222
rolebinding "fake-user:psp:unprivileged" created

kubectl-user auth can-i use podsecuritypolicy/example
yes

Now retry creating the pod:

kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
pod "pause" created

It works as expected! But any attempts to create a privileged pod should still be denied:

kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      privileged
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
      securityContext:
        privileged: true
EOF
Error from server (Forbidden): error when creating "STDIN": pods "privileged" is forbidden: unable to validate against any pod security policy: [spec.containers[0].securityContext.privileged: Invalid value: true: Privileged containers are not allowed]

Delete the pod before moving on:

kubectl-user delete pod pause

Run another pod

Let’s try that again, slightly differently:

kubectl-user run pause --image=k8s.gcr.io/pause
deployment "pause" created

kubectl-user get pods
No resources found.

kubectl-user get events | head -n 2
LASTSEEN   FIRSTSEEN   COUNT     NAME              KIND         SUBOBJECT                TYPE      REASON                  SOURCE                                  MESSAGE
1m         2m          15        pause-7774d79b5   ReplicaSet                            Warning   FailedCreate            replicaset-controller                   Error creating: pods "pause-7774d79b5-" is forbidden: no providers available to validate pod request

What happened? We already bound the psp:unprivileged role for our fake-user, why are we getting the error Error creating: pods "pause-7774d79b5-" is forbidden: no providers available to validate pod request? The answer lies in the source - replicaset-controller. Fake-user successfully created the deployment (which successfully created a replicaset), but when the replicaset went to create the pod it was not authorized to use the example podsecuritypolicy.

In order to fix this, bind the psp:unprivileged role to the pod’s service account instead. In this case (since we didn’t specify it) the service account is default:

kubectl-admin create rolebinding default:psp:unprivileged \
    --role=psp:unprivileged \
    --serviceaccount=psp-example:default
rolebinding "default:psp:unprivileged" created

Now if you give it a minute to retry, the replicaset-controller should eventually succeed in creating the pod:

kubectl-user get pods --watch
NAME                    READY     STATUS    RESTARTS   AGE
pause-7774d79b5-qrgcb   0/1       Pending   0         1s
pause-7774d79b5-qrgcb   0/1       Pending   0         1s
pause-7774d79b5-qrgcb   0/1       ContainerCreating   0         1s
pause-7774d79b5-qrgcb   1/1       Running   0         2s

Clean up

Delete the namespace to clean up most of the example resources:

kubectl-admin delete ns psp-example
namespace "psp-example" deleted

Note that PodSecurityPolicy resources are not namespaced, and must be cleaned up separately:

kubectl-admin delete psp example
podsecuritypolicy "example" deleted

Example Policies



https://github.com/dgkanatsios/CKAD-exercises/blob/master/g.state.md



et apres celui de k_s in action
