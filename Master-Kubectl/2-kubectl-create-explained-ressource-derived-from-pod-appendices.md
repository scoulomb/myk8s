[Previous section](./1-kubectl-create-explained-ressource-derived-from-pod.md)
 
# Create resources deriving from a pod  
 
## Link between resource type and  restart policy

Resource being: (Cron)Job, Deployment. 

### Deployment 

Taking deployment from section [Explanation why we have CrashLoppBackOff](#Explanation-why-we-have-CrashLoppBackOff-when-non-loop-command-is-runned
) and changing the restart policy to `Never`.

<details><summary>Manifest</summary>
<p>


````commandline
k delete deployment --all

echo ' 
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: alpine-deployment
  name: alpine-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: alpine-deployment
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: alpine-deployment
    spec:
      containers:
      - image: alpine
        name: alpine
        command:
        - /bin/true
        resources: {}
      restartPolicy: Never
status: {}' > alpine-deployment.yaml
k create -f alpine-deployment.yaml
sleep 25
k get pods
````

</p>
</details>

Output is :

````commandline
The Deployment "alpine-deployment" is invalid: spec.template.spec.restartPolicy: Unsupported value: "Never": supported values: "Always"
````

Same for `OnFailure`:

````commandline
The Deployment "alpine-deployment" is invalid: spec.template.spec.restartPolicy: Unsupported value: "OnFailure": supported values: "Always"
````

**Deployment only accept `Always` as a `restartPolict`**

This explain why the field does not appear in generated yaml.

### (Cron)Job

Then taking the CronJob from [create cron job section](#create-cron-job) and change restart Policy to always.

<details><summary>Manifest</summary>
<p>

````commandline
echo '
--- 
apiVersion: batch/v1beta1
kind: CronJob
metadata: 
  creationTimestamp: ~
  name: alpine-cronjob
spec: 
  jobTemplate: 
    metadata: 
      creationTimestamp: ~
      name: alpine-cronjob
    spec: 
      template: 
        metadata: 
          creationTimestamp: ~
        spec: 
          containers: 
            - 
              command: 
                - /bin/sleep
                - "30"
              image: alpine
              name: alpine-cronjob
              resources: {}
          restartPolicy: Always
  schedule: "* * * * *" '> cron_job_restartPolicy.yaml
k create -f cron_job_restartPolicy

````

</p>
</details>

And output is 

````commandline
The CronJob "alpine-cronjob" is invalid: spec.jobTemplate.spec.template.spec.restartPolicy: Unsupported value: "Always": supported values: "OnFailure", "Never"
````
 
**CronJob only accept `Never` and `OnFailure` as a `restartPolict`**
 
 
# Explanation why we have CrashLoppBackOff

## Case of a deployment 

`restartPolicy` is thus `Always` as explained in [previous section](#Link-between-resource-type-and-restart-policy).

### Command is /bin/false

<details><summary>Manifest from deployment section</summary>
<p>

````commandline

k delete deployment --all

echo ' 
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: alpine-deployment
  name: alpine-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: alpine-deployment
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: alpine-deployment
    spec:
      containers:
      - image: alpine
        name: alpine
        command:
        - /bin/false
        resources: {}
status: {}' > alpine-deployment.yaml
k create -f alpine-deployment.yaml
sleep 25
k get pods

````

</p>
</details>

Output is :

````commandline
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                READY   STATUS             RESTARTS   AGE
alpine-deployment-966d74b8b-5fc94   0/1     Error              2          45s
alpine-deployment-966d74b8b-cxb27   0/1     CrashLoopBackOff   2          45s
alpine-deployment-966d74b8b-zjl75   0/1     Error              2          45s
[22:37] ~
➤
````

### Command is /bin/true 

And same by replacing `false` by `true` in the manifest:

````commandline
[22:30] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                 READY   STATUS             RESTARTS   AGE
alpine-deployment-54c8f4dd6d-2sqst   0/1     Completed          3          81s
alpine-deployment-54c8f4dd6d-kc2hk   0/1     CrashLoopBackOff   3          81s
alpine-deployment-54c8f4dd6d-lfvhs   0/1     CrashLoopBackOff   3          81s
[22:31] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                 READY   STATUS             RESTARTS   AGE
alpine-deployment-54c8f4dd6d-2sqst   0/1     CrashLoopBackOff   4          2m27s
alpine-deployment-54c8f4dd6d-kc2hk   0/1     CrashLoopBackOff   4          2m27s
alpine-deployment-54c8f4dd6d-lfvhs   0/1     CrashLoopBackOff   4          2m27s
[22:33] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                 READY   STATUS             RESTARTS   AGE
alpine-deployment-54c8f4dd6d-2sqst   0/1     CrashLoopBackOff   5          4m39s
alpine-deployment-54c8f4dd6d-kc2hk   0/1     CrashLoopBackOff   5          4m39s
alpine-deployment-54c8f4dd6d-lfvhs   0/1     CrashLoopBackOff   5          4m39s
````

### Conclusion

- We have completed intermediate status for `/bin/true` 
- We have error intermediate status for `/bin/false`

But both end up in `CrashLoopBackOff`. Why?

It is because the container stops running, as the command is ended.

Given that `restartPolicy` is `always`. 

The `Kubelet` will restart the container in the pod too many time which is causing the `CrashLoopBackOff`, whatever sucess or failure of the command.
(with the sleep effect is reduced but still there)

Doing docker inspect we can see the Command is set to `/bin/sh`.
Repeating same experience with `/bin/sh` command leads to same results as `/bin/true`.

<details><summary>Alpine container command</summary>
<p>
Note the change of behavior: http://www.johnzaccone.io/entrypoint-vs-cmd-back-to-basics/
In the past no command was defined in alpine image:

````commandline
➤ docker run  alpine                                                                                                                                                          vagrant@archlinux[22:15] ~
➤ echo $status
0
```
with old image:

````commandline
[22:56] ~
➤ docker run alpine:2.6                                                                                                                                                       vagrant@archlinux
docker: Error response from daemon: No command specified.
See 'docker run --help'.
[22:56] ~
➤ echo $status                                                                                                                                                                vagrant@archlinux
125
````
if using Alpine 2.6, note we have a CrashLoopBackoff with 2.6 (not change in behavior with k8s)

</p>
</details>



## Case of Job

If we repeat same experience with successful and failed job.
`restartPolicy` can be `Never` or `OnFailure`  as explained in [previous section](#Link-between-resource-type-and-restart-policy).

So we will have 2x2=4 tests. 

Start by deleting ALL job `k delete job --all`.

### Case 1: Command is /bin/false and restart policy is OnFailure

<details><summary>Manifest from Job section</summary>
<p>

````commandline
echo '
apiVersion: batch/v1
kind: Job
metadata:
  creationTimestamp: null
  name: alpine-job
spec:
  template:
    metadata:
      creationTimestamp: null
    spec:
      containers:
      - command:
        - /bin/false
        - "10"
        image: alpine
        name: alpine-job
        resources: {}
      restartPolicy: OnFailure
status: {}' > false_onfailure.yaml
k delete -f false_onfailure.yaml
k create -f false_onfailure.yaml
````

</p>
</details>


<details><summary>Output</summary>
<p>


````commandline
job.batch/alpine-job created
[12:20] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS              RESTARTS   AGE
alpine-job-dvjcl   0/1     ContainerCreating   0          5s
[12:20] ~
➤ k get jobs                                                                                                                                                                  vagrant@archlinuxNAME         COMPLETIONS   DURATION   AGE
alpine-job   0/1           12s        12s
[12:21] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS   RESTARTS   AGE
alpine-job-dvjcl   0/1     Error    2          35s
[12:21] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS             RESTARTS   AGE
alpine-job-dvjcl   0/1     CrashLoopBackOff   2          47s
[12:21] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS             RESTARTS   AGE
alpine-job-dvjcl   0/1     CrashLoopBackOff   4          2m10s
[12:23] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS             RESTARTS   AGE
alpine-job-dvjcl   0/1     CrashLoopBackOff   5          6m5s
[12:26] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
No resources found in default namespace.
[12:27] ~
➤ k describe job alpine-job                                                                                                                                                   vagrant@archlinux
Name:           alpine-job
Namespace:      default
Selector:       controller-uid=7fa8e09d-2479-4723-8f8d-f90158056794
Labels:         controller-uid=7fa8e09d-2479-4723-8f8d-f90158056794
                job-name=alpine-job
Annotations:    <none>
Parallelism:    1
Completions:    1
Start Time:     Sun, 03 May 2020 12:20:50 +0000
Pods Statuses:  0 Running / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  controller-uid=7fa8e09d-2479-4723-8f8d-f90158056794
           job-name=alpine-job
  Containers:
   alpine-job:
    Image:      alpine
    Port:       <none>
    Host Port:  <none>
    Command:
      /bin/false
      10
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Events:
  Type     Reason                Age                From            Message
  ----     ------                ----               ----            -------
  Normal   SuccessfulCreate      6m40s              job-controller  Created pod: alpine-job-dvjcl
  Normal   SuccessfulDelete      22s                job-controller  Deleted pod: alpine-job-dvjcl
  Warning  BackoffLimitExceeded  21s (x2 over 22s)  job-controller  Job has reached the specified backoff limit

➤ k get job alpine-job -o yaml | grep -A 2 command                                                                                                                            vagrant@archlinux
                f:command: {}
                f:image: {}
                f:imagePullPolicy: {}
--
      - command:
        - /bin/false
        - "10"
[12:30] ~
➤ k get job alpine-job -o yaml | grep -A 2 restartPolicy                                                                                                                      vagrant@archlinux
            f:restartPolicy: {}
            f:schedulerName: {}
            f:securityContext: {}
--
      restartPolicy: OnFailure
      schedulerName: default-scheduler
      securityContext: {}

````

</p>
</details>

### Case 2: Command is /bin/true and restart policy is OnFailure

We make modifications in manifest.

<details><summary>Output</summary>
<p>


````commandline
[23:52] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS      RESTARTS   AGE
alpine-job-g6996   0/1     Completed   0          5s
[23:52] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS      RESTARTS   AGE
alpine-job-g6996   0/1     Completed   0          9s
[23:52] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS      RESTARTS   AGE
alpine-job-g6996   0/1     Completed   0          11s
````

</p>
</details>

### Case 3: Command is /bin/true and restart policy is Never

We make modifications in manifest.

<details><summary>Output</summary>
<p>


````commandline
➤ k get jobs                                                                                                                                                                  vagrant@archlinuxNAME         COMPLETIONS   DURATION   AGE
alpine-job   1/1           6s         75s

➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS      RESTARTS   AGE
alpine-job-64hfk   0/1     Completed   0          36s
````

</p>
</details>

### Case 4: Command is /bin/false and restart policy is Never

We make modifications in manifest.

<details><summary>Output</summary>
<p>


````commandline
job.batch/alpine-job created
[11:47] ~
➤ k get job                                                                                                                                                                   vagrant@archlinuxNAME         COMPLETIONS   DURATION   AGE
alpine-job   0/1           10s        10s
[11:47] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS   RESTARTS   AGE
alpine-job-nv4mf   0/1     Error    0          9s
alpine-job-wrxwm   0/1     Error    0          14s
[11:47] ~
[12:00] ~
➤ k describe job alpine-job                                                                                                                                                   vagrant@archlinuxName:           alpine-job
[...]
Events:
  Type     Reason                Age    From            Message
  ----     ------                ----   ----            -------
  Normal   SuccessfulCreate      12m    job-controller  Created pod: alpine-job-wrxwm
  Normal   SuccessfulCreate      12m    job-controller  Created pod: alpine-job-nv4mf
  Normal   SuccessfulCreate      12m    job-controller  Created pod: alpine-job-v8jqs
  Normal   SuccessfulCreate      12m    job-controller  Created pod: alpine-job-k6rtv
  Normal   SuccessfulCreate      11m    job-controller  Created pod: alpine-job-xnhk5
  Normal   SuccessfulCreate      10m    job-controller  Created pod: alpine-job-ln444
  Normal   SuccessfulCreate      7m42s  job-controller  Created pod: alpine-job-7h8j9
  Warning  BackoffLimitExceeded  2m21s  job-controller  Job has reached the specified backoff limit
[12:00] ~
➤ k get job                                                                                                                                                                   vagrant@archlinuxNAME         COMPLETIONS   DURATION   AGE
alpine-job   0/1           13m        13m
[12:00] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS   RESTARTS   AGE
alpine-job-7h8j9   0/1     Error    0          9m17s
alpine-job-k6rtv   0/1     Error    0          13m
alpine-job-ln444   0/1     Error    0          11m
alpine-job-nv4mf   0/1     Error    0          14m
alpine-job-v8jqs   0/1     Error    0          14m
alpine-job-wrxwm   0/1     Error    0          14m
alpine-job-xnhk5   0/1     Error    0          13m
````

</p>
</details>

### Conclusion

- Case 2,3: A successful job is completed whatever the policy is
- Case 1: A failed job's container is restarted when failed 
    - if restart policy is OnFailure.
    - it generates a CrashLoppBackOff.
- Case 4: A failed job's container is  NOT restarted when failed
    - if restart policy is Never it is not restarted,
    - But Job Controller will continue to create new pod. So this `Never` restart policy which is the default with Kubectl can be dangerous (ETCD limit).

### Termination policy

However for pod which failed to terminate  (or if too long) we can use :
- `.spec.activeDeadlineSeconds` 
- `.spec.backoffLimit` 
To terminate the job

By default there is a `backoffLimit` set to 6.
It explains why case 4 did not start more than 6 pods.
For case 1 it has also effect as it counts number of container restart.

The documentation on this topic can be found [here](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/#job-termination-and-cleanup).

### Deletion policy 

Also note completed pods (case 2, 3) and error pod (case 4) are still there.
In case 1 they are deleted.

For clean-up do `k delete job` which will remove pods in cascade.
But it is a Kubectl feature.
There is a now a TTL mecahansim in beta to remove job which will delete the pod.

<details><summary>Note on delete option</summary>
<p>


See the following note on this topic (source openshift_job_playbook.yaml#78)

````xhtml
> As per kubectl specification: https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/#job-termination-and-cleanup
> "When you delete the job using kubectl, all the pods it created are deleted too." by default
> However this a kubectl feature. This is not performed when using the API
> https://github.com/kubernetes/kubernetes/issues/20902
> To fix this (rather than deleting pods directly) we have to use delete option. Thus the body present in delete call
> https://github.com/kubernetes/kubernetes/blob/release-1.7/staging/src/k8s.io/apimachinery/pkg/apis/meta/v1/types.go#L359
> To test pod logs remove delete options, to get pod logs after job completion
> or while sleep 1; do oc logs $(oc get pods | grep zz-job-launcher- | awk '{print $1}'); done
> Also note that .spec.ttlSecondsAfterFinished could automatically delete the job and all its related pods
> https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/#ttl-mechanism-for-finished-jobs
> However this is still alpha k8s v1.12, where we use 1.7 (oct 19)

Delete option in API:
url: "https://{{endpoint}}:8443/apis/batch/v1/namespaces/{{namespace}}/jobs/{{job_name}}"
method: DELETE
body:
apiVersion: batch/v1
kind: DeleteOptions
propagationPolicy: "Background"
````

</p>
</details>

## `/bin/true` and `/bin/false`

Note on `/bin/true` and `/bin/false`:
Where we can see clearly return code.

````commandline
[13:24] ~
➤ /bin/true 10                                                                                                                                                                vagrant@archlinux
[13:24] ~
➤ echo $status                                                                                                                                                                vagrant@archlinux
0
[13:25] ~
➤ /bin/false 10                                                                                                                                                               vagrant@archlinux
[13:25] ~
➤ echo $status                                                                                                                                                                vagrant@archlinux
1
````

Arguments have no effect. 0 is a successful exit code. 

## Wrap up

In first part [here](0-kubectl-run-explained.md#What-is-actually-the-restart-policy).

We had seen:

- Use a Deployment, ReplicaSet or StatefulSet for Pods that are not expected to terminate, for example, web servers. 
=> So here restart policy can only be always (and explain why remove in 1.18 version of doc)
- Use a Job for Pods that are expected to terminate once their work is complete; for example, batch computations. Jobs are appropriate only for Pods with restartPolicy equal to OnFailure or Never.

And in the ligth off [Explanation why we have CrashLoppBackOff](#Explanation-why-we-have-CrashLoppBackOff).

We understand why a deployment for a container which is not running permanently is not a good fit.

Since even if container is successful, it wiil lead to CrashLoopBackOff even if we have a  successful execution.

## Multi-container behavior

Understand that restartPolicy impact at container level restart.

For instance if policy is Never, container is not restarted.
And from [doc](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#example-states):

- When we have one container, pod is not restarted and failed
> Pod is running and has one Container. Container exits with failure.
> If restartPolicy is:
> - Always: Restart Container; Pod phase stays Running.
> - OnFailure: Restart Container; Pod phase stays Running.
> - **Never: Pod phase becomes Failed**. [Job case 4](#Case-of-Job)

As such taking manifest for case 4 (we can test other case but will limit to Never)

````commandline
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME            READY   STATUS              RESTARTS   AGE
test-mc-rgnbs   0/2     Terminating         0          3m16s
test-mc-xh9fb   0/1     Error               0          11s
test-mc-zzf4p   0/1     ContainerCreating   0          2s
[13:00] ~
➤ k describe pod test-mc-xh9fb | grep  "Status:"                                                                                                                              vagrant@archlinux
Status:       Failed
````

As pod status is failed other pods are triggered.

- When we have 2 container, pod continue to run and failing container is not restarted.

> Pod is running and has two Containers. Container 1 exits with failure.
> If restartPolicy is:
> - Always: Restart Container; Pod phase stays Running.
> - OnFailure: Restart Container; Pod phase stays Running.
> - **Never: Do not restart Container; Pod phase stays Running**.

:

<details><summary>Adding a second container manifest</summary>
<p>

````commandline
k delete job --all
echo '
apiVersion: batch/v1
kind: Job
metadata:
  creationTimestamp: null
  name:  test-mc
spec:
  template:
    metadata:
      creationTimestamp: null
    spec:
      containers:
      - command:
        - /bin/false
        - "10"
        image: alpine
        name: alpine-job
        resources: {}
      - command:
        - /bin/sleep
        - "3600"
        image: alpine
        name: long-job
        resources: {}
      restartPolicy: Never
status: {}' > test-mc.yaml
k delete -f  test-mc.yaml
k create -f  test-mc.yaml
````
</p>
</details>

And output is:

````commandline
[12:59] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME            READY   STATUS   RESTARTS   AGE
test-mc-rgnbs   1/2     Error    0          115s
[12:59] ~
➤ k describe pod test-mc-rgnbs | grep  "Status:"                                                                                                                              vagrant@archlinux
Status:       Running
````

Pod continues to run and no other pods are triggered, 
But actually pod will be considered as failed after sleep finished and it will retrigger new pod.
This can be tested by reducing sleep duration ok.

[next section](3-Understand-resource-pod-template.md)
 