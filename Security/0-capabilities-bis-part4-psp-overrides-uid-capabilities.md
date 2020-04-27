# Capabilities -  Pod security policy - Impact of a psp on user id and capabilities

Minikube is started with psp admission controller.
Either just did part 3 or follow instructions to setup Minikube in [part 2](./0-capabilities-bis-part2-admission-controller-setup.md#FINAL-SOLUTION) with pod security policy admission controller enabled.

Here we will show impact of a psp on user id and capabilities.

## Prepare the environment: define the pod security policy (psp) and user non root svc account 

From the doc I will take [the most restrictive one](https://kubernetes.io/docs/concepts/policy/pod-security-policy/#example-policies
).

````buildoutcfg
echo '
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: 'docker/default,runtime/default'
    apparmor.security.beta.kubernetes.io/allowedProfileNames: 'runtime/default'
    seccomp.security.alpha.kubernetes.io/defaultProfileName:  'runtime/default'
    apparmor.security.beta.kubernetes.io/defaultProfileName:  'runtime/default'
spec:
  privileged: false
  # Required to prevent escalations to root.
  allowPrivilegeEscalation: false
  # This is redundant with non-root + disallow privilege escalation,
  # but we can provide it for defense in depth.
  requiredDropCapabilities:
    - ALL
  # Allow core volume types.
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    # Assume that persistentVolumes set up by the cluster admin are safe to use.
    - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    # Require the container to run without root privileges.
    rule: 'MustRunAsNonRoot'
  seLinux:
    # This policy assumes the nodes are using AppArmor rather than SELinux.
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
      # Forbid adding the root group.
      - min: 1
        max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      # Forbid adding the root group.
      - min: 1
        max: 65535
  readOnlyRootFilesystem: false' > psp.yaml

kadm delete -f psp.yaml
kadm create -f psp.yaml
````

Then I will create a user sa and give him edit cluster role in default ns:

```buildoutcfg
kubectl create serviceaccount default-non-root
kubectl create rolebinding -n default non-root-editor --clusterrole=edit --serviceaccount=default:default-non-root
```

To make it clear which user we’re acting as and save some typing, create 2 aliases:

````buildoutcfg
alias kadm='kubectl -n default'
alias k='kubectl --as=system:serviceaccount:default:default-non-root -n default'
````

Test by creating a POD

````buildoutcfg
k create -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  name:      pause
spec:
  containers:
    - name:  pause
      image: k8s.gcr.io/pause
EOF
````

Output is 


````buildoutcfg
root@minikube:~# k create -f- <<EOF
> apiVersion: v1
> kind: Pod
> metadata:
>   name:      pause
> spec:
>   containers:
>     - name:  pause
>       image: k8s.gcr.io/pause
> EOF
Error from server (Forbidden): error when creating "STDIN": pods "pause" is forbidden: unable to validate against any pod security policy: []
````

Bind the non root user service account to this restricted psp.

````buildoutcfg
kadm create role psp:restricted \
    --verb=use \
    --resource=podsecuritypolicies.extensions \
    --resource-name=restricted


kadm create rolebinding default-non-root:psp:restricted \
    --role=psp:restricted \
    --serviceaccount=default:default-non-root
````

So that:

````buildoutcfg
root@minikube:~# k create -f- <<EOF
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

My environment is ready for testing

if later issue on pulling due to DNS issue: https://github.com/containrrr/watchtower/issues/352
````buildoutcfg
vagrant reload; vagrant ssh; sudo -s; 
````
Minikube should be ok but need to redefine aliases.


## Tests

We will now perform same test as [part 1/Docker with image user 0](./0-capabilities-bis-part1-basic.md#Docker image with user 0) 
This test use a docker image with user 0 (root).

### With adm user

````buildoutcfg
source capa_test.sh
kadm delete pod pod-with-defaults
kadm run pod-with-defaults --image alpine --restart Never -- /bin/sleep 999999
capa_test pod-with-defaults
````

Output is the same as part 1

````buildoutcfg
root@minikube:~# capa_test pod-with-defaults
+ kubectl exec pod-with-defaults -- id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
+ grep --color=auto CapBnd
+ kubectl exec pod-with-defaults -- grep Cap /proc/1/status
CapBnd: 00000000a80425fb
+ kubectl exec pod-with-defaults -- traceroute 127.0.0.1
traceroute to 127.0.0.1 (127.0.0.1), 30 hops max, 46 byte packets
 1  localhost (127.0.0.1)  0.015 ms  0.011 ms  0.009 ms
+ kubectl exec pod-with-defaults -- date +%T -s 12:00:00
12:00:00
date: can't set date: Operation not permitted
+ kubectl exec pod-with-defaults -- chmod 777 home
+ echo 0
0
+ kubectl exec pod-with-defaults -- chown nobody /
+ echo 0
0
````

As expected and [part 1/Docker with image user 0](./0-capabilities-bis-part1-basic.md#Docker-image-with-user-0) . We are using UID defined in container which is 0.

### With non root user 


````buildoutcfg
source capa_test.sh
k delete pod pod-with-defaults-non-root
k run pod-with-defaults-non-root --image alpine --restart Never -- /bin/sleep 999999
capa_test pod-with-defaults-non-root
````


The image will not run:

````buildoutcfg
Events:
  Type     Reason     Age                From               Message
  ----     ------     ----               ----               -------
  Normal   Scheduled  39s                default-scheduler  Successfully assigned default/pod-with-defaults-non-root to minikube
  Normal   Pulled     13s (x3 over 34s)  kubelet, minikube  Successfully pulled image "alpine"
  Warning  Failed     13s (x3 over 34s)  kubelet, minikube  Error: container has runAsNonRoot and image will run as root
  Normal   Pulling    0s (x4 over 37s)   kubelet, minikube  Pulling image "alpine"
````

Because of the pod security policy!
See [notes below](#Optional-Tip-to-run-container-bake-with-root-user-with MustRunAsNonRoot-psp) for a top to still run this pod even if we have:
````buildoutcfg
runAsUser:
    # Require the container to run without root privileges.
    rule: 'MustRunAsNonRoot'
````
And a container with id 0.

### Modify the PSP to allow a range

Rather than preventing to run as root, I will define an allowed range.
See `# CHANGE MADE HERE` in yaml below:

````buildoutcfg
echo '
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: 'docker/default,runtime/default'
    apparmor.security.beta.kubernetes.io/allowedProfileNames: 'runtime/default'
    seccomp.security.alpha.kubernetes.io/defaultProfileName:  'runtime/default'
    apparmor.security.beta.kubernetes.io/defaultProfileName:  'runtime/default'
spec:
  privileged: false
  # Required to prevent escalations to root.
  allowPrivilegeEscalation: false
  # This is redundant with non-root + disallow privilege escalation,
  # but we can provide it for defense in depth.
  requiredDropCapabilities:
    - ALL
  # Allow core volume types.
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    # Assume that persistentVolumes set up by the cluster admin are safe to use.
    - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    # CHANGE MADE HERE
    rule: 'MustRunAs'
    ranges:
      - min: 2
        max: 4
  seLinux:
    # This policy assumes the nodes are using AppArmor rather than SELinux.
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
      # Forbid adding the root group.
      - min: 1
        max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      # Forbid adding the root group.
      - min: 1
        max: 65535
  readOnlyRootFilesystem: false' > psp.yaml

kadm delete -f psp.yaml
kadm create -f psp.yaml
````

Then
````buildoutcfg
root@minikube:~# kadm get podsecuritypolicy restricted
+ kubectl -n default get podsecuritypolicy restricted
NAME         PRIV    CAPS   SELINUX    RUNASUSER   FSGROUP     SUPGROUP    READONLYROOTFS   VOLUMES
restricted   false          RunAsAny   MustRunAs   MustRunAs   MustRunAs   false            configMap,emptyDir,projected,secret,downwardAPI,persistentVolumeClaim
````

And the re-run 

````buildoutcfg
source capa_test.sh
k delete pod pod-with-defaults-non-root
k run pod-with-defaults-non-root --image alpine --restart Never -- /bin/sleep 999999
capa_test pod-with-defaults-non-root
````

And here it become really interesting!

Output is:

````buildoutcfg
root@minikube:~# capa_test pod-with-defaults-non-root
+ capa_test pod-with-defaults-non-root
+ set -x
+ kubectl exec pod-with-defaults-non-root -- id
uid=2(daemon) gid=2(daemon) groups=1(bin),2(daemon),4(adm)
+ grep --color=auto CapBnd
+ kubectl exec pod-with-defaults-non-root -- grep Cap /proc/1/status
CapBnd: 0000000000000000
+ kubectl exec pod-with-defaults-non-root -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-with-defaults-non-root -- date +%T -s 12:00:00
12:00:00
date: can't set date: Operation not permitted
+ kubectl exec pod-with-defaults-non-root -- chmod 777 home
chmod: home: Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-with-defaults-non-root -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1
````

It run my pod with `uid=2` and `no capabilities`.
Whereas in pod spec I do not have `runAsDirective` or `Capabilities`.

But given the psp and rolebinding specific to this user, it overrides the pod spec.

It equivalent to have:
- used the runAsUser in pod spec security context section as in [part 1/Docker with image user 0](./0-capabilities-bis-part1-basic.md#Specific-user-with-docker-image-with-user-0).
- And dropping all capabilities as done in  [part 1/Test adding/removing capabilities to root](./0-capabilities-bis-part1-basic.md#Test-adding-and-removing-capabilities-to-root ) 

It is a way to prevent a container to run as root, but misleading as the user running can not be found in pod spec and not the on in container.

(k8s in action, 13.3.2, Deploying a pod with a container image with an out-of-range user id)
(except using user with 5 in a new built container image,
even if not artifactory I could do the same with pull policy and 
run same test as in part 1 with custom image but would not show much more uid 0 is a particular case 
which is shown [here](./0-capabilities-bis-part1-basic.md#Specific-user-with-docker-image-with-user-7777))


### Run with a user outside the range allowed in PSP

````buildoutcfg
k  delete pod pod-outside-range
echo '
apiVersion: v1
kind: Pod
metadata:
  name: pod-outside-range
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 405 ' > pod-outside-range.yaml
                             
k  create -f pod-outside-range.yaml
````

Output is

````buildoutcfg
root@minikube:~# k  create -f pod-outside-range.yaml
+ kubectl --as=system:serviceaccount:default:default-non-root -n default create -f pod-outside-range.yaml
Error from server (Forbidden): error when creating "pod-outside-range.yaml": pods "pod-outside-range" is forbidden: unable to validate against any pod security policy: [spec.containers[0].securityContext.runAsUser: Invalid value: 405: must be in the ranges: [{2 4}]]
````

So it is not possible to force for a non noot user.
(k8s in action, 13.3.2, Deploying a pod with runAsUser outside of the policy’s range)

### Run with an already assigned user and use runAs in the range


````buildoutcfg
k  delete pod-assigned-range.yaml
echo '
apiVersion: v1
kind: Pod
metadata:
  name: pod-assigned-range
spec:
  containers:
  - name: main
    image: alpine
    command: ["/bin/sleep", "999999"]
    securityContext:
      runAsUser: 2' > pod-assigned-range.yaml
                             
k  create -f pod-assigned-range.yaml
````

Output

````buildoutcfg
root@minikube:~# k  create -f pod-assigned-range.yaml
+ kubectl --as=system:serviceaccount:default:default-non-root -n default create -f pod-assigned-range.yaml
pod/pod-assigned-range created

root@minikube:~# capa_test pod-assigned-range
+ capa_test pod-assigned-range
+ set -x
+ kubectl exec pod-assigned-range -- id
uid=2(daemon) gid=2(daemon) groups=1(bin),2(daemon),4(adm)
+ kubectl exec pod-assigned-range -- grep Cap /proc/1/status
+ grep --color=auto CapBnd
CapBnd: 0000000000000000
+ kubectl exec pod-assigned-range -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-assigned-range -- date +%T -s 12:00:00
date: can't set date: Operation not permitted
12:00:00
+ kubectl exec pod-assigned-range -- chmod 777 home
chmod: home: Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-assigned-range -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1
root@minikube:~# k get pods
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pods
NAME                         READY   STATUS    RESTARTS   AGE
pod-assigned-range           1/1     Running   0          79s
pod-with-defaults            1/1     Running   0          61m
pod-with-defaults-non-root   1/1     Running   0          24m
root@minikube:~# capa_test pod-with-defaults-non-root
+ capa_test pod-with-defaults-non-root
+ set -x
+ kubectl exec pod-with-defaults-non-root -- id
uid=2(daemon) gid=2(daemon) groups=1(bin),2(daemon),4(adm)
+ grep --color=auto CapBnd
+ kubectl exec pod-with-defaults-non-root -- grep Cap /proc/1/status
CapBnd: 0000000000000000
+ kubectl exec pod-with-defaults-non-root -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-with-defaults-non-root -- date +%T -s 12:00:00
12:00:00
date: can't set date: Operation not permitted
+ kubectl exec pod-with-defaults-non-root -- chmod 777 home
chmod: home: Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-with-defaults-non-root -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1
````

It is showing that:
- we can use `runAsUser` directive if the user is in the range defined in PSP
- several pod can use same user.

Observations made here confirms what is explained here in the introduction.
https://www.openshift.com/blog/jupyter-on-openshift-part-6-running-as-an-assigned-user-id

And actually Openshift is just reusing psp here.

See [next section](./0-capabilities-bis-part5-manage-not-run-as-uid-0.md) for how to deal when can not be root

# Optional: Going further

## Optional Tip to run container bake with root user with MustRunAsNonRoot psp

````buildoutcfg
k edit psp restricted # or kadm if alias
# Make this change

runAsUser:
    # Require the container to run without root privileges.
    rule: 'MustRunAsNonRoot'
````

````buildoutcfg
set -x 
# be careful overrides default alias, otherwise will run as admin and will not see it as this ressource is not namespaced or using default
alias kadm='kubectl -n default'
alias k='kubectl --as=system:serviceaccount:default:default-non-root -n default'

k delete pod pod-with-defaults-non-root
k run pod-with-defaults-non-root --image alpine --restart Never -- /bin/sleep 999999
````


The image will not run, output is 

````buildoutcfg
root@minikube:~# k run pod-with-defaults-non-root --image alpine --restart Never -- /bin/sleep 999999
+ kubectl --as=system:serviceaccount:default:default-non-root -n default run pod-with-defaults-non-root --image alpine --restart Never -- /bin/sleep 999999
pod/pod-with-defaults-non-root created
root@minikube:~# k describe pods pod-with-defaults-non-root | grep -C 3 Failed
+ grep --color=auto -C 3 Failed
+ kubectl --as=system:serviceaccount:default:default-non-root -n default describe pods pod-with-defaults-non-root
  ----     ------     ----               ----               -------
  Normal   Scheduled  72s                default-scheduler  Successfully assigned default/pod-with-defaults-non-root to minikube
  Normal   Pulled     12s (x4 over 56s)  kubelet, minikube  Successfully pulled image "alpine"
  Warning  Failed     12s (x4 over 56s)  kubelet, minikube  Error: container has runAsNonRoot and image will run as root
  Normal   Pulling    2s (x5 over 70s)   kubelet, minikube  Pulling image "alpine"
root@minikube:~# k get pods | grep pod-with-defaults-non-root
+ grep --color=auto pod-with-defaults-non-root
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pods
pod-with-defaults-non-root   0/1     CreateContainerConfigError   0          89s
````

The tip is to use a user

````buildoutcfg
k run pod-with-defaults-non-root-run-as --dry-run --image alpine --restart Never -o yaml -- /bin/sleep 999999 > o.yaml
echo '
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: pod-with-defaults-non-root-run-as
  name: pod-with-defaults-non-root-run-as
spec:
  containers:
  - args:
    - /bin/sleep
    - "999999"
    image: alpine
    name: pod-with-defaults-non-root-run-as
    resources: {}
    securityContext:
      runAsUser: 404 #  <-- Add this line
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {} ' > pod-with-defaults-non-root-run-as.yaml
k create -f pod-with-defaults-non-root-run-as.yaml
````

Output is 

````buildoutcfg
root@minikube:~# capa_test pod-with-defaults-non-root-run-as
+ capa_test pod-with-defaults-non-root-run-as
+ set -x
+ kubectl exec pod-with-defaults-non-root-run-as -- id
uid=404 gid=0(root) groups=1(bin)
+ grep --color=auto CapBnd
+ kubectl exec pod-with-defaults-non-root-run-as -- grep Cap /proc/1/status
CapBnd: 00000000a80425fb
+ kubectl exec pod-with-defaults-non-root-run-as -- traceroute 127.0.0.1
traceroute: socket(AF_INET,3,1): Operation not permitted
command terminated with exit code 1
+ kubectl exec pod-with-defaults-non-root-run-as -- date +%T -s 12:00:00
12:00:00
date: can't set date: Operation not permitted
+ kubectl exec pod-with-defaults-non-root-run-as -- chmod 777 home
chmod: home: Operation not permitted
command terminated with exit code 1
+ echo 1
1
+ kubectl exec pod-with-defaults-non-root-run-as -- chown nobody /
chown: /: Operation not permitted
command terminated with exit code 1
+ echo 1
1

root@minikube:~# k get pods | grep pod-with-defaults-non-root-run-as
+ grep --color=auto pod-with-defaults-non-root-run-as
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pods
pod-with-defaults-non-root-run-as   1/1     Running                      0          16s
````

uid is 404! and run as no root
(k8s in action, 13.3.2, Using the MustRunAsNonRoot rule in the runAsUser field)

Note: K8s in action uses real user not svc account  
It shows that we can use group=system:authenticated
And this comment [here](./0-capabilities-bis-part2-admission-controller-setup.md#why-)
And user set at server startup, what is weird is that showing  `--user bob` at the end and assumes no privileged.


## PSP policy update

From k8s in action, 13.3.1:
> When someone posts a pod resource to the API server, the PodSecurityPolicy admission control plugin validates the pod definition against the configured PodSecurityPolicies. If the pod conforms to the cluster’s policies, it’s accepted and stored into etcd; otherwise it’s rejected immediately. The plugin may also modify the pod resource according to defaults configured in the policy.

We have an example of capabilities [drop](#Modify-the-PSP-to-allow-a-range) showing pod modifications,
For first part of the sentence as check is done at ETCD level a pod created before more restrictive policy should continue to run.

Scenario is the following:
- Create a PSP which enables to run a root
- Create a pod running as root
- Modify  the psp to to prevent to run as root
- check can not create pod root
- but what happens to previously launched pod?

### Step1: Create a PSP which enables to run a root

````buildoutcfg
set -x 
# be careful overrides default alias, otherwise will run as admin and will not see it as this ressource is not namespaced or using default
alias kadm='kubectl -n default'
alias k='kubectl --as=system:serviceaccount:default:default-non-root -n default'
kadm edit psp restricted

# Make this change

runAsUser:
    rule: 'MustRunAsNonRoot'

# to 

runAsUser:
 rule: MustRunAs
 ranges:
   - max: 5
     min: 0
````

### Step 2: Create a pod running as root

Run as root
````buildoutcfg
k run pod-root --image alpine --restart Never -- /bin/sleep 999999
````

It is working 

````buildoutcfg
root@minikube:~# k exec -it pod-root -- id
+ kubectl --as=system:serviceaccount:default:default-non-root -n default exec -it pod-root -- id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
````


### Step 3:  Modify  the psp to to prevent to run as root


````buildoutcfg
kadm edit psp restricted

# Make this change
runAsUser:
 rule: MustRunAs
 ranges:
   - max: 5
     min: 0

# to 

runAsUser:
    rule: 'MustRunAsNonRoot'

````

### Step 4: check can not create pod root

````buildoutcfg
k run pod-root-after-psp-edit --image alpine --restart Never -- /bin/sleep 999999
````
The image will not run, output is 

````buildoutcfg
root@minikube:~# kadm edit psp restricted
+ kubectl -n default edit psp restricted
podsecuritypolicy.policy/restricted edited
root@minikube:~# k run pod-root-after-psp-edit --image alpine --restart Never -- /bin/sleep 999999
+ kubectl --as=system:serviceaccount:default:default-non-root -n default run pod-root-after-psp-edit --image alpine --restart Never -- /bin/sleep 999999
pod/pod-root-after-psp-edit created
root@minikube:~#  k describe pod/pod-root-after-psp-edit | grep -C 3 Failed
+ grep --color=auto -C 3 Failed
+ kubectl --as=system:serviceaccount:default:default-non-root -n default describe pod/pod-root-after-psp-edit
  Normal   Scheduled  57s               default-scheduler  Successfully assigned default/pod-root-after-psp-edit to minikube
  Normal   Pulling    7s (x5 over 56s)  kubelet, minikube  Pulling image "alpine"
  Normal   Pulled     2s (x5 over 53s)  kubelet, minikube  Successfully pulled image "alpine"
  Warning  Failed     2s (x5 over 53s)  kubelet, minikube  Error: container has runAsNonRoot and image will run as root
root@minikube:~# k get pods | grep pod-root
+ grep --color=auto pod-root
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pods
pod-root                            1/1     Running                      0          14m
pod-root-after-psp-edit             0/1     CreateContainerConfigError   0          95s

root@minikube:~# k exec -it pod-root-after-psp-edit -- id
+ kubectl --as=system:serviceaccount:default:default-non-root -n default exec -it pod-root-after-psp-edit -- id
error: unable to upgrade connection: container not found ("pod-root-after-psp-edit")
````

We can not create a root pod

### Step 5: but what happens to previously launched pod?

We can see in last output previous pod is still running.
And still root !

````buildoutcfg
root@minikube:~# k exec -it pod-root -- id
+ kubectl --as=system:serviceaccount:default:default-non-root -n default exec -it pod-root -- id
uid=0(root) gid=0(root) groups=0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)
root@minikube:~#
````
as uid is 0.
OK

We can see pod modification here:

````buildoutcfg
root@minikube:~# k get pod pod-root-after-psp-edit -o yaml
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pod pod-root-after-psp-edit -o yaml
apiVersion: v1
kind: Pod
[...]
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true

root@minikube:~# k get pod pod-root -o yaml
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pod pod-root -o yaml
apiVersion: v1
kind: Pod
[...]
    securityContext:
      allowPrivilegeEscalation: false
      runAsUser: 0
````

## Pod modifications adding default capabilities through PSP

- https://kubernetes.io/docs/concepts/policy/pod-security-policy/
- https://sysdig.com/blog/enable-kubernetes-pod-security-policy/
Make this change:

````buildoutcfg

kadm edit psp restricted

# Add 

spec:
  allowPrivilegeEscalation: false
  defaultAddCapabilities: # Add
  - NET_ADMIN # Add
  - IPC_LOCK  # Add

# change 

runAsUser:
  rule: MustRunAsNonRoot


to 

runAsUser:
  ranges:
  - max: 42
    min: 1
  rule: MustRunAs
````

And then do 
````
k run pod-root-adding-default-capa --image alpine --restart Never -- /bin/sleep 999999
````

We can see default capabilities have been added:

````buildoutcfg
root@minikube:~# k get pods | grep pod-root-adding-default-capa
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pods
+ grep --color=auto pod-root-adding-default-capa
pod-root-adding-default-capa        1/1     Running                      0          2m15s
root@minikube:~# k get pod pod-root-adding-default-capa -o yaml | grep -A 6 securityContext
+ grep --color=auto -A 6 securityContext
+ kubectl --as=system:serviceaccount:default:default-non-root -n default get pod pod-root-adding-default-capa -o yaml
        f:securityContext: {}
        f:terminationGracePeriodSeconds: {}
    manager: kubectl
    operation: Update
    time: "2020-04-27T13:59:10Z"
  - apiVersion: v1
    fieldsType: FieldsV1
--
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        add:
        - IPC_LOCK
        - NET_ADMIN
      runAsUser: 1
--
  securityContext:
    fsGroup: 1
    supplementalGroups:
    - 1
  serviceAccount: default
  serviceAccountName: default
  terminationGracePeriodSeconds: 30
````