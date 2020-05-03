# Explanation why we have CrashLoppBackOff

## Case of a deployment 

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
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                                READY   STATUS             RESTARTS   AGE
alpine-deployment-966d74b8b-5fc94   0/1     Error              2          45s
alpine-deployment-966d74b8b-cxb27   0/1     CrashLoopBackOff   2          45s
alpine-deployment-966d74b8b-zjl75   0/1     Error              2          45s
[22:37] ~
➤
````

### Command is /bin/true 

And same by replacing false by true:

````commandline
[22:30] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                                 READY   STATUS             RESTARTS   AGE
alpine-deployment-54c8f4dd6d-2sqst   0/1     Completed          3          81s
alpine-deployment-54c8f4dd6d-kc2hk   0/1     CrashLoopBackOff   3          81s
alpine-deployment-54c8f4dd6d-lfvhs   0/1     CrashLoopBackOff   3          81s
[22:31] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                                 READY   STATUS             RESTARTS   AGE
alpine-deployment-54c8f4dd6d-2sqst   0/1     CrashLoopBackOff   4          2m27s
alpine-deployment-54c8f4dd6d-kc2hk   0/1     CrashLoopBackOff   4          2m27s
alpine-deployment-54c8f4dd6d-lfvhs   0/1     CrashLoopBackOff   4          2m27s
[22:33] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                                 READY   STATUS             RESTARTS   AGE
alpine-deployment-54c8f4dd6d-2sqst   0/1     CrashLoopBackOff   5          4m39s
alpine-deployment-54c8f4dd6d-kc2hk   0/1     CrashLoopBackOff   5          4m39s
alpine-deployment-54c8f4dd6d-lfvhs   0/1     CrashLoopBackOff   5          4m39s
````

### Conclusion

We have completed vs error for `/bin/true` and `/bin/false`

But both end up in `CrashLoopBackOff`. Why?
It is because the container stops running, as the command is ended,
Then he `Kubelet` needs to restart the container in the pod too many time which is causing the `CrashLoopBackOff`, whatever sucess or failure of the command.
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

If we repeat same experience with successful and failed job:

## Case of Job

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
        - /bin/true # or false
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

### Command is /bin/false and restart policy is OnFailure

````commandline
➤ k create -f false_onfailure.yaml                                                                                                                                            vagrant@archlinuxjob.batch/alpine-job created
[23:46] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS              RESTARTS   AGE
alpine-job-95zss   0/1     ContainerCreating   0          5s
[23:46] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS   RESTARTS   AGE
alpine-job-95zss   0/1     Error    0          8s
[23:46] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS   RESTARTS   AGE
alpine-job-95zss   0/1     Error    1          10s
[23:46] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS             RESTARTS   AGE
alpine-job-95zss   0/1     CrashLoopBackOff   1          17s
[23:46] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS             RESTARTS   AGE
alpine-job-95zss   0/1     CrashLoopBackOff   5          3m52s
````


### Command is /bin/true and restart policy is OnFailure

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

### Command is /bin/true and restart policy is Never

````commandline
➤ k get jobs                                                                                                                                                                  vagrant@archlinuxNAME         COMPLETIONS   DURATION   AGE
alpine-job   1/1           6s         75s

➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS      RESTARTS   AGE
alpine-job-64hfk   0/1     Completed   0          36s
````

### Command is /bin/false and restart policy is Never

````commandline
[00:19] ~
➤ k get jobs                                                                                                                                                                  vagrant@archlinuxNAME         COMPLETIONS   DURATION   AGE
alpine-job   0/1           38s        38s
[00:19] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME               READY   STATUS              RESTARTS   AGE
alpine-job-5d8qz   0/1     Error               0          35s
alpine-job-627w9   0/1     ContainerCreating   0          5s
alpine-job-dq24f   0/1     Error               0          25s
alpine-job-qwlqd   0/1     Error               0          40s
````


### Conclusion

- A successful job is completed.
- A failed job's container is restarted, when failed if restart policy is OnFailure and, and it generates a CrashLoppBackOff.
- A failed job's container is  NOT restarted, when failed if restart policy is Never it is not restarted,
But Job Controller will continue to create new pod. So this `Never` restart policy which is the default with Kubectl can be dangerous (ETCD limit).



## Link with restart policy

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

So only always is accepted explaining why it does not appear in generated yaml.

Then taking the job from [create cron job section](#create-cron-job) and change restart Policy to always.


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

And ouput is 

````commandline
The CronJob "alpine-cronjob" is invalid: spec.jobTemplate.spec.template.spec.restartPolicy: Unsupported value: "Always": supported values: "OnFailure", "Never"
````

In first part [here](0-kubectl-run-explained.md#What-is-actually-the-restart-policy).

We had seen:

- Use a Deployment, ReplicaSet or StatefulSet for Pods that are not expected to terminate, for example, web servers. => So here restart policy can only be always (and explain why remove in 1.18 version of doc)
- Use a Deployment, ReplicaSet or StatefulSet for Pods that are not expected to terminate, for example, web servers. => So here restart policy can only be always (and explain why remove in 1.18 version of doc)
- Use a Job for Pods that are expected to terminate once their work is complete; for example, batch computations. Jobs are appropriate only for Pods with restartPolicy equal to OnFailure or Never.

And in the ligth off [Explanation why we have CrashLoppBackOff](#Explanation-why-we-have-CrashLoppBackOff).

We understand why a deployment for a container which is not running permanently is not a good fit.

Since even if container is successful, it wiil lead to CrashLoopBackOff unlike a succesful job.

Understand that restartPolicy impact at container level restart.
Also here, if policy is Never, container is not restarted.

From [doc](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#example-states):

- When we have one container -> pod failed
- When we have 2 container -> pod continue to run and container is not restarted