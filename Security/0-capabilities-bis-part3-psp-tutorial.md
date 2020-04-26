# Test PSP

## k8s PSP tutorial

We will now follow this tutorial from [kubernetes.io](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#example).
Since we have finally a cluster with the PodSecurityPolicy admission controller enabled and have cluster admin privileges.

### Set up

Start a minikube

````buildoutcfg
cd /c/git_pub/myk8s/Setup/MinikubeSetup
vagrant ssh 
sudo -s
minikube delete
minikube start --driver=none 
````

Set up a namespace and a service account to act as for this example. 
We’ll use this service account to mock a non-admin user.

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

### Create a policy 

Define the example PodSecurityPolicy object in a file. 
This is a policy that simply prevents the creation of privileged pods.
The name of a PodSecurityPolicy object must be a valid DNS subdomain name.

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

```buildoutcfg
kubectl-admin create -f example-psp.yaml
```


### Create a POD where PSP Admission controller plugin is not enabled in the cluster

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

Output is: 

````buildoutcfg
root@minikube:~# kubectl-user create -f- <<EOF
> apiVersion: v1
> kind: Pod
> metadata:
>   name:      pause
> spec:
>   containers:
>     - name:  pause
>       image: k8s.gcr.io/pause
> EOF
pod/pause created
````

So it worked. 

If I create a user with no-edit (no role)
````buildoutcfg
kubectl create serviceaccount -n psp-example fake-user-no-edit
alias kubectl-user-no-edit='kubectl --as=system:serviceaccount:psp-example:fake-user-no-edit -n psp-example'
````
It will not work.

````buildoutcfg
root@minikube:~# kubectl-user-no-edit create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF

Error from server (Forbidden): error when creating "STDIN": pods is forbidden: User "system:serviceaccount:psp-example:fake-user-no-edit" cannot create resource "pods" in API group "" in the namespace "psp-example"
````

I was able to create a pod with `kubectl-user`.
This the case because `kubectl-user` had edit role and PSP admission controller is not present.
  
### Create a POD with PSP enabled

````buildoutcfg
minikube start --driver=none --extra-config=apiserver.enable-admission-plugins="NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds,PodSecurityPolicy"
````

````buildoutcfg
root@minikube:~# kubectl-user create -f- <<EOF
> apiVersion: v1
> kind: Pod
> metadata:
>   name:      pause
> spec:
>   containers:
>     - name:  pause
>       image: k8s.gcr.io/pause
> EOF
Error from server (Forbidden): error when creating "STDIN": pods "pause" is forbidden: no providers available to validate pod request
root@minikube:~# Error from server (Forbidden): error when creating "STDIN": pods "pause" is forbidden: no providers available to validate pod requestkubectl-admin create -f example-psp.yaml^C
root@minikube:~# kubectl-admin create -f example-psp.yaml
podsecuritypolicy.policy/example created
root@minikube:~# kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
Error from server (Forbidden): error when creating "STDIN": pods "pause" is forbidden: unable to validate against any pod security policy: []
````

What happened? Although the PodSecurityPolicy was created, neither the pod’s service account nor fake-user have permission to use the new policy.

And as mentioned in [part 2 why section](./0-capabilities-bis-part2-admission-controller-setup.md#why-), a non root user by default can perform nothing.

Also we can see that error message is changing when a PSP is there and not there (I had to recreate it after restart ok).


Note root can do it:

````buildoutcfg
root@minikube:~# kubectl-admin create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF

pod/pause created
root@minikube:~# kubectl delete pod/pause -n psp-example
pod "pause" deleted
````

### Grant role to non root user to use psp

So our non root user can by default do nothing.
We need to define the role to give him the rigth to use the psp which enable to crate everything except privileged container.

#### Check can not use 

````buildoutcfg
root@minikube:~# kubectl-user auth can-i use podsecuritypolicy/example
Warning: resource 'podsecuritypolicies' is not namespace scoped in group 'policy'
no
````

#### Create role
Create the rolebinding to grant fake-user the use verb on the example policy:

Note: This is not the recommended way! See the next section for the preferred approach.

This will not work
````buildoutcfg
root@minikube:~# kubectl-admin create role psp:unprivileged \
>     --verb=use \
>     --resource=podsecuritypolicy \
>     --resource-name=example
e "psp:unprivileged" createderror: can not perform 'use' on 'podsecuritypolicies' in group 'policy'
````

DISCREPANCY: we have to use instead `podsecuritypolicies.extensions`

````buildoutcfg
kubectl-admin create role psp:unprivileged \
  --verb=use \
  --resource=podsecuritypolicies.extensions \
  --resource-name=example
````

#### Create role binding

````buildoutcfg
kubectl-admin create rolebinding fake-user:psp:unprivileged \
    --role=psp:unprivileged \
    --serviceaccount=psp-example:fake-user
````

#### Check access

````buildoutcfg
root@minikube:~# kubectl-admin create rolebinding fake-user:psp:unprivileged     --role=psp:unprivileged     --serviceaccount=psp-example:fake-userrolebinding.rbac.authorization.k8s.io/fake-user:psp:unprivileged created
root@minikube:~# kubectl-user auth can-i use podsecuritypolicy/example
Warning: resource 'podsecuritypolicies' is not namespace scoped in group 'policy'
no
root@minikube:~# kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
pod/pause created
root@minikube:~# kubectl-admin delete pod pause
pod "pause" deleted
````

I can now create a pod.
If I delete rb.

````buildoutcfg

root@minikube:~# kubectl-admin delete rolebinding fake-user:psp:unprivileged
rolebinding.rbac.authorization.k8s.io "fake-user:psp:unprivileged" deleted
root@minikube:~# kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
Error from server (Forbidden): error when creating "STDIN": pods "pause" is forbidden: unable to validate against any pod security policy: []
````

I can anymore and recreating it

````buildoutcfg
root@minikube:~# kubectl-admin create rolebinding fake-user:psp:unprivileged     --role=psp:unprivileged     --serviceaccount=psp-example:fake-userrolebinding.rbac.authorization.k8s.io/fake-user:psp:unprivileged created
root@minikube:~# kubectl-user create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
pod/pause created
root@minikube:~#
````

I can!

DISCREPANCY: I do not have this behavior compared to the doc

````buildoutcfg
kubectl-user auth can-i use podsecuritypolicy/example
yes
````


Now retry creating the pod:

It works as expected!
 
But any attempts to create a privileged pod should still be denied:

````buildoutcfg
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
````

Output is
````buildoutcfg
root@minikube:~# kubectl-user create -f- <<EOF
> apiVersion: v1
> kind: Pod
> metadata:
>   name:      privileged
> spec:
>    containers:
>     - name:  pause
>       image: k8s.gcr.io/pause
>       securityContext:
>         privileged: true
> EOF
Error from server (Forbidden): error when creating "STDIN": pods "privileged" is forbidden: unable to validate against any pod security policy: [spec.containers[0].securityContext.privileged: Invalid value: true: Privileged containers are not allowed]
````


Delete the pod before moving on:

````buildoutcfg
kubectl-user delete pod pause
````

### Create a deployment 

Run another pod

Let’s try that again, slightly differently:

````buildoutcfg
root@minikube:~# kubectl-user run pause --image=k8s.gcr.io/pause
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
deployment.apps/pause created
````

````buildoutcfg
root@minikube:~# kubectl-user get pods
No resources found in psp-example namespace.
````

DISCREPANCY: we have the ns mentioned

````buildoutcfg
kubectl-user get pods
No resources found.
````

````buildoutcfg
root@minikube:~# kubectl-user get events | head -n 2
LAST SEEN   TYPE      REASON              OBJECT                        MESSAGE
3s          Warning   FailedCreate        replicaset/pause-5df45c44db   Error creating: pods "pause-5df45c44db-" is forbidden: unable to validate against any pod security policy: []
````

DISCREPANCY: We should not have no provider error because PSP is there

````buildoutcfg
kubectl-user get events | head -n 2
LASTSEEN   FIRSTSEEN   COUNT     NAME              KIND         SUBOBJECT                TYPE      REASON                  SOURCE                                  MESSAGE
1m         2m          15        pause-7774d79b5   ReplicaSet                            Warning   FailedCreate            replicaset-controller                   Error creating: pods "pause-7774d79b5-" is forbidden: no providers available to validate pod request
````

What happened? We already bound the psp:unprivileged role for our fake-user, why are we getting the error Error creating: pods "pause-7774d79b5-" is forbidden: no providers available to validate pod request? The answer lies in the source - replicaset-controller. Fake-user successfully created the deployment (which successfully created a replicaset), but when the replicaset went to create the pod it was not authorized to use the example podsecuritypolicy.

In order to fix this, bind the psp:unprivileged role to the pod’s service account instead. In this case (since we didn’t specify it) the service account is default:

````buildoutcfg
kubectl-admin create rolebinding default:psp:unprivileged \
    --role=psp:unprivileged \
    --serviceaccount=psp-example:default
rolebinding "default:psp:unprivileged" created
````

Now if you give it a minute to retry, the replicaset-controller should eventually succeed in creating the pod:

````buildoutcfg
root@minikube:~# kubectl-user get pods --watch
NAME                     READY   STATUS              RESTARTS   AGE
pause-5df45c44db-94zd9   0/1     ContainerCreating   0          10s
````

DISCREPANCY: we should have a single pod at that step and not:

````buildoutcfg
kubectl-user get pods --watch
NAME                    READY     STATUS    RESTARTS   AGE
pause-7774d79b5-qrgcb   0/1       Pending   0         1s
pause-7774d79b5-qrgcb   0/1       Pending   0         1s
pause-7774d79b5-qrgcb   0/1       ContainerCreating   0         1s
pause-7774d79b5-qrgcb   1/1       Running   0         2s

````

Then I had a pull image error, I did not push investigation further.
Even after creation of new deployment, and reducing policy.

### Clean up

Delete the namespace to clean up most of the example resources:

`kubectl-admin delete ns psp-example`

SecurityPolicy resources are not namespaced, and must be cleaned up separately:

`kubectl-admin delete psp example`

We would now have a more explicit message for deployment:

````buildoutcfg
kubectl create namespace psp-example
root@minikube:~# kubectl-user run pause --image=k8s.gcr.io/pause
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
Error from server (Forbidden): deployments.apps is forbidden: User "system:serviceaccount:psp-example:fake-user" cannot create resource "deployments" in API group "apps" in the namespace "psp-example"
````


## Status:
- All OK except
- "Then I a pull image error, I did not push investigation further"" -> OK, do not go further
- VOIR DISCREPANCY
DISCREPANCY: We should not have no provider error because PSP is there OK
All ok except the can I use: https://www.mankier.com/1/kubectl-auth-can-i
pas voir plus 
a la limie fixer la doc
et can i -> open issue
could worth to add how to enable psp with minikube





