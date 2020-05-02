# Kubectl run behavior
 
## Obeservations 

Starting from [there](./Seccurity/0-capabilities-bis-part4-psp-overrides-uid-capabilities.md#with-adm-user)

Test `kubectl run` using different kubernetes version:

````
echo '
set -x
echo -e "\nRelease \n"
cat /etc/os-release
echo -e "\nKube version \n"
sudo kubectl version 
sudo kubectl run -h | grep  "restart="
echo -e "\nDefault \n"
sudo kubectl run alpine --image alpine --dry-run=client -o yaml -- /bin/sleep 10 
echo -e "\nNever \n"
sudo kubectl run alpine --image alpine --restart=Never --dry-run=client -o yaml -- /bin/sleep 10 # Command is at the end
echo -e "\nOnFailure \n"
sudo kubectl run alpine --image alpine --restart=OnFailure --dry-run=client -o yaml -- /bin/sleep 10 # Command is at the end
echo -e "\nAlways \n"
sudo kubectl run alpine --image alpine --restart=Always --dry-run=client -o yaml -- /bin/sleep 10 # Command is at the end' > run_test.sh

chmod u+x run_test.sh
sudo bash run_test.sh > o.txt # Using bash to run same script when we have fish by default
cat o.txt
````
### Version `1.18`

<details><summary>output</summary>
<p>

````
 cat o.txt                                                                                                   vagrant@archlinux

Release

NAME="Arch Linux"
PRETTY_NAME="Arch Linux"
ID=arch
BUILD_ID=rolling
ANSI_COLOR="0;36"
HOME_URL="https://www.archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://bugs.archlinux.org/"
LOGO=archlinux

Kube version

Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.2", GitCommit:"52c56ce7a8272c798dbc29846288d7cd9fbae032", GitTreeState:"clean", BuildDate:"2020-04-16T11:56:40Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:50:46Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
  kubectl run -i -t busybox --image=busybox --restart=Never
      --attach=false: If true, wait for the Pod to start running, and then attach to the Pod as if 'kubectl attach ...' were called.  Default false, unless '-i/--stdin' is set, in which case the default is true. With '--restart=Never' the exit code of the container process is returned.
      --restart='Always': The restart policy for this Pod.  Legal values [Always, OnFailure, Never].  If set to 'Always' a deployment is created, if set to 'OnFailure' a job is created, if set to 'Never', a regular pod is created. For the latter two --replicas must be 1.  Default 'Always', for CronJobs `Never`.

Default

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  containers:
  - args:
    - /bin/sleep
    - "10"
    image: alpine
    name: alpine
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

Never

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  containers:
  - args:
    - /bin/sleep
    - "10"
    image: alpine
    name: alpine
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}

OnFailure

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  containers:
  - args:
    - /bin/sleep
    - "10"
    image: alpine
    name: alpine
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: OnFailure
status: {}

Always

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  containers:
  - args:
    - /bin/sleep
    - "10"
    image: alpine
    name: alpine
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
[17:59] ~
➤                                                                                                             vagrant@archlinu
````

</p>
</details>

### Version `1.16`

<details><summary>output</summary>
<p>


I had to remove `client` from `--dry-run` has not customizable in `1.16`.
````
sylvain@HP:~
$ sudo bash run_test.sh > o.txt # Using bash to run same script when we have fish by default
+ echo -e '\nRelease \n'
+ cat /etc/os-release
+ echo -e '\nKube version \n'
+ sudo kubectl version
+ sudo kubectl run -h
+ grep restart=
+ echo -e '\nDefault \n'
+ sudo kubectl run alpine --image alpine --dry-run -o yaml -- /bin/sleep 10
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
+ echo -e '\nNever \n'
+ sudo kubectl run alpine --image alpine --restart=Never --dry-run -o yaml -- /bin/sleep 10
+ echo -e '\nOnFailure \n'
+ sudo kubectl run alpine --image alpine --restart=OnFailure --dry-run -o yaml -- /bin/sleep 10
kubectl run --generator=job/v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
+ echo -e '\nAlways \n'
+ sudo kubectl run alpine --image alpine --restart=Always --dry-run -o yaml -- /bin/sleep 10
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
sylvain@HP:~
$ cat o.txt 

Release 

NAME="Ubuntu"
VERSION="18.04.4 LTS (Bionic Beaver)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 18.04.4 LTS"
VERSION_ID="18.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
VERSION_CODENAME=bionic
UBUNTU_CODENAME=bionic

Kube version 

Client Version: version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.1", GitCommit:"d647ddbd755faf07169599a625faf302ffc34458", GitTreeState:"clean", BuildDate:"2019-10-02T17:01:15Z", GoVersion:"go1.12.10", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.0", GitCommit:"9e991415386e4cf155a24b1da15becaa390438d8", GitTreeState:"clean", BuildDate:"2020-03-25T14:50:46Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
  kubectl run -i -t busybox --image=busybox --restart=Never
  kubectl run pi --image=perl --restart=OnFailure -- perl -Mbignum=bpi -wle 'print bpi(2000)'
  kubectl run pi --schedule="0/5 * * * ?" --image=perl --restart=OnFailure -- perl -Mbignum=bpi -wle 'print bpi(2000)'
      --attach=false: If true, wait for the Pod to start running, and then attach to the Pod as if 'kubectl attach ...' were called.  Default false, unless '-i/--stdin' is set, in which case the default is true. With '--restart=Never' the exit code of the container process is returned.
      --restart='Always': The restart policy for this Pod.  Legal values [Always, OnFailure, Never].  If set to 'Always' a deployment is created, if set to 'OnFailure' a job is created, if set to 'Never', a regular pod is created. For the latter two --replicas must be 1.  Default 'Always', for CronJobs `Never`.

Default 

apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  replicas: 1
  selector:
    matchLabels:
      run: alpine
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        run: alpine
    spec:
      containers:
      - args:
        - /bin/sleep
        - "10"
        image: alpine
        name: alpine
        resources: {}
status: {}

Never 

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  containers:
  - args:
    - /bin/sleep
    - "10"
    image: alpine
    name: alpine
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}

OnFailure 

apiVersion: batch/v1
kind: Job
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  template:
    metadata:
      creationTimestamp: null
      labels:
        run: alpine
    spec:
      containers:
      - args:
        - /bin/sleep
        - "10"
        image: alpine
        name: alpine
        resources: {}
      restartPolicy: OnFailure
status: {}

Always 

apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  replicas: 1
  selector:
    matchLabels:
      run: alpine
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        run: alpine
    spec:
      containers:
      - args:
        - /bin/sleep
        - "10"
        image: alpine
        name: alpine
        resources: {}
status: {}
````

</p>
</details>

### Conclusion 

In version  <= `1.16` depending on restart policy in kubectl run it was creating a pod, job or deployment,
Now in `1.18` (last release) it is always creating a pod, and restart policy is just controlling the restart policy part of the manifest.


## Doc confirming behavior

Finally found the doc mentionning it clearly and confirming obsevrations in `1.17`: https://v1-17.docs.kubernetes.io/docs/reference/kubectl/conventions/#generators, 
> If you explicitly set --generator, kubectl uses the generator you specified. If you invoke kubectl run and don’t specify a generator, kubectl automatically selects which generator to use based on the other flags you set.
> The following table lists flags and the generators that are activated if you didn’t specify one yourself:

So doing command below using pod generator, with always as `restartPolicy` I will have a pod and not a deployment in v `1.16`

````
$ sudo kubectl run alpine --generator=run-pod/v1 --dry-run  --image alpine --restart=Always -o yaml -- /bin/sleep 10
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  containers:
  - args:
    - /bin/sleep
    - "10"
    image: alpine
    name: alpine
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

````

which is `1.18` behavior: It is like we always have the pod generator from `1.18`

This is why in `1.16`, we have this warning for backward compatibility:

````
sylvain@HP:~
$ sudo kubectl run alpine --dry-run  --image alpine --restart=Always -o yaml -- /bin/sleep 10
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  replicas: 1
  selector:
    matchLabels:
      run: alpine
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        run: alpine
    spec:
      containers:
      - args:
        - /bin/sleep
        - "10"
        image: alpine
        name: alpine
        resources: {}
status: {}
````


And as per doc in v`1.18` generator is deprecated
https://kubernetes.io/docs/reference/kubectl/conventions/#kubectl-run
> All kubectl generators are deprecated. See the Kubernetes v`1.17` documentation for a list of generators and how they were used.

Thus doing this in v.18 has no effect and create a pod

````
➤ sudo kubectl run alpine --generator=deployment/v1beta1 --image alpine --restart=Always --dry-run=client -o yaml -- /bin/sleep 10
Flag --generator has been deprecated, has no effect and will be removed in the future.
apiVersion: v1
kind: Pod
metadata:

````

We can see that `1.18` CLI is I am using in observation is not alinged with behavior + doc, I wanted to update the doc but it is already done there, less than one month ago
https://github.com/kubernetes/kubectl/commit/2cd642e11a18e8fa19bdffbe68c665579be64006
In doc I see schedule  it also marked as deprecated
https://github.com/kubernetes/kubectl/blame/master/pkg/cmd/run/run.go#L199

## What is actually the restart policy

Pod Restart policys  impact this behavior:
https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#example-states

We can also there is recomendation between restart policy and object created (pod, deployment and job)
From: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-lifetime 

- Use a Deployment, ReplicaSet or StatefulSet for Pods that are not expected to terminate, for example, web servers. (==> always?, In 1.14 doc version we can see there was replication controller and it was associated to always)
- Use a Job for Pods that are expected to terminate once their work is complete; for example, batch computations. Jobs are appropriate only for Pods with restartPolicy equal to OnFailure or Never.
- Use a DaemonSet for Pods that need to run one per eligible node.

Which explained the default generator choice in `1.17`


## Next steps 

So run is now reserved to pod creation.

- How to create deployment, job?
- What is the default restart policy when using this specific command?
- What happens to a deployment if restartPolicy=Never or Always?

See [next-section](1-kubectl-create-explained.md)

[OK CCL]
