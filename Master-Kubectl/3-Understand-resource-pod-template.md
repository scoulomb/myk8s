# Understand resource pod template

````
➤ k run alpine --image alpine --restart=Never --dry-run -o yaml -- /bin/sleep 10
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
````

````
➤ k create job alpine-job --image alpine --dry-run -o yaml -- /bin/sleep 10   vagrant@archlinuxapiVersion: batch/v1
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
        - /bin/sleep
        - "10"
        image: alpine
        name: alpine-job
        resources: {}
      restartPolicy: Never
status: {}
````

A job contains a `pod.metadata` and `pod.spec` in `job.spec.template.metadata` and `job.spec.template.spec`
( k explain job.spec.template)

````
➤ k create cronjob alpine-cronjob --image alpine  --schedule="* * * * *" --dry-run -o yaml -- /bin/sleep 30
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  creationTimestamp: null
  name: alpine-cronjob
spec:
  jobTemplate:
    metadata:
      creationTimestamp: null
      name: alpine-cronjob
    spec:
      template:
        metadata:
          creationTimestamp: null
        spec:
          containers:
          - command:
            - /bin/sleep
            - "30"
            image: alpine
            name: alpine-cronjob
            resources: {}
          restartPolicy: OnFailure
  schedule: '* * * * *'
status: {}
````

A cronjob contains `job.spec` in `cronjob.spec.jobTemplate` (then expand job.spec)
(k explain cronjob.spec.jobTemplate --recursive)

````
➤ echo '                                                                      vagrant@archlinux
  apiVersion: apps/v1
  kind: ReplicaSet
  metadata:
    name: alpine-rs
    labels:
      # Not used in pod matching, this is for the rs
      applabel: alpine-rs
  spec:
    # modify replicas according to your case
    replicas: 3
    selector:
      # https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/#pod-template
      matchLabels:
        app: rssample
    template:
      metadata:
        labels:
          app: rssample
      spec:
        containers:
        - name: alpine
          command:
          - /bin/sleep
          - "3600"
          image: alpine' > alpine-rs.yaml
  k create -f alpine-rs.yaml --dry-run
replicaset.apps/alpine-rs created (dry run)
````

A ReplicaSet  contains a `pod.metadata` and `pod.spec` in `ReplicaSet.spec.template.metadata` and `ReplicaSet.spec.template.spec`
( k explain ReplicaSet.spec.template)

https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/
https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md


````
➤ k create deployment alpine-deployment --image=alpine --dry-run -o yaml      vagrant@archlinuxapiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: alpine-deployment
  name: alpine-deployment
spec:
  replicas: 1
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
        resources: {}
status: {}
````

A Deployment  contains a `pod.metadata` and `pod.spec` in `Deployment.spec.template.metadata` and `Deployment.spec.template.spec`   

(k explain Deployment.spec.template)

Note the discrpency between Cronjob/Job and Deployment/ReplicaSet

Explain seems case insensitive
Unlike kind in manifest:

Error if applying a manifest with deployment kind (small d)

````shell script
no kind "deployment" is registered for version "apps/v1"
````

OK

# Label matching

CronJob label matching with pods and similarities with Deployment 

We can observe similarities here with:
- deployment, rs, pod 
- cronjob, job, pod

In this [advanced deployment section](../Deployment/advanced/article.md#deploy-first-version).

We had the following for a deployment:

````shell script
cat << EOF | k apply -f - --record
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: server
  name: server

[...]
[vagrant@archlinux ~]$ k get pod  $pod_0_name -o  jsonpath='{.metadata.labels}{"\n"}'
map[app:server pod-template-hash:f9999df48]
[vagrant@archlinux ~]$ k get replicaset  $rs_name -o jsonpath='{.spec.selector.matchLabels}{"\n"}'
map[app:server pod-template-hash:f9999df48]
````

So deploy create a rs with as selector the given label `app` and `podTemplateHash`, matching the pod.

Note for a job we do not have this `app` labels (in section above).
 
Inside it uses the controller uid and not the job-name

````shell script
➤ k get jobs hello-1590703800 -o yaml                                        vagrant@archlinux
apiVersion: batch/v1
kind: Job
metadata:
  creationTimestamp: "2020-05-28T22:10:02Z"
  labels:
    controller-uid: 2cda2034-026a-4353-83ce-8f8239ec834d
    job-name: hello-1590703800
  name: hello-1590703800
  namespace: default
  ownerReferences:
  - apiVersion: batch/v1beta1
    blockOwnerDeletion: true
    controller: true
    kind: CronJob
    name: hello
    uid: 0fc7e734-8829-47fe-800a-fdd42b236406
  resourceVersion: "550540"
  selfLink: /apis/batch/v1/namespaces/default/jobs/hello-1590703800
  uid: 2cda2034-026a-4353-83ce-8f8239ec834d
spec:
  backoffLimit: 6
  completions: 1
  parallelism: 1
  selector:
    matchLabels:
      controller-uid: 2cda2034-026a-4353-83ce-8f8239ec834d
  template:
    metadata:
      creationTimestamp: null
      labels:
        controller-uid: 2cda2034-026a-4353-83ce-8f8239ec834d
        job-name: hello-1590703800
➤ k get pods --selector=controller-uid=2cda2034-026a-4353-83ce-8f8239ec834d  vagrant@archlinux
NAME                     READY   STATUS      RESTARTS   AGE
hello-1590703800-nrgsr   0/1     Completed   0          46s
````

The job name is not used for the matching and only controller-uid (equivalent to `app` and `podTemplateHash` label in rs) is used, there is not `app` labels 
Although it is present in pod label (see labels in job pod template and pod in shell script below).
This is why the command proposed in task [automated-tasks-with-cron-jobs](https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/#creating-a-cron-job) is working: `pods=$(kubectl get pods --selector=job-name=hello-4111706356 --output=jsonpath={.items[*].metadata.name})`.


````shell script
k get cronjob  
k get jobs 
export job_name=(k get jobs -o jsonpath='{.items[2].metadata.name}{"\n"}')
echo $job_name
# We could have taken job-name for other places
k get job $job_name -o yaml | grep -B 3 -A 6 metadata     
# Let get the controller uid
export controlleruid=(k get jobs -o jsonpath='{.items[2].metadata.labels.controller-uid}{"\n"}')
echo $controlleruid

k get pod -l controller-uid=$controlleruid
k get pod --selector=controller-uid=$controlleruid
k get pod -l job-name=$job_name    
k get pod -l job-name=$job_name -o yaml | head -n 6                                                                                                                 vagrant@archlinuxNAME                              READY   STATUS      RESTARTS   AGE

# This why we can get pod name
set pods (k get pods --selector=job-name=$job_name --output=jsonpath='{.items[*].metadata.name}')
echo $pods
````

- I used item `[2]` because by default we keep 3 last jobs and 3 last pods from [doc](https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/#jobs-history-limits).
- If cronjob is deleted we have [cascade deletion](https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/#deleting-a-cron-job).
- For job deletion [see here](../Master-Kubectl/2-kubectl-create-explained-ressource-derived-from-pod-appendices.md#deletion-policy)

Output is:

````shell script
[11:39] ~
➤ k get cronjob                                                              vagrant@archlinuxNAME             SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
alpine-cronjob   * * * * *   False     0        37s             37m
[11:39] ~
➤ k get jobs                                                                 vagrant@archlinuxNAME                        COMPLETIONS   DURATION   AGE
alpine-cronjob-1590752220   1/1           6s         2m40s
alpine-cronjob-1590752280   1/1           9s         100s
alpine-cronjob-1590752340   1/1           6s         40s
[11:39] ~
➤ export job_name=(k get jobs -o jsonpath='{.items[2].metadata.name}{"\n"}') vagrant@archlinux
  echo $job_name
alpine-cronjob-1590752340
[11:39] ~
➤ k get job $job_name -o yaml | grep -B 3 -A 6 metadata                      vagrant@archlinuxapiVersion: batch/v1
kind: Job
metadata:
  creationTimestamp: "2020-05-29T11:39:01Z"
  labels:
    controller-uid: 1b028949-6006-4b8a-9732-b8038f9ac420
    job-name: alpine-cronjob-1590752340
  name: alpine-cronjob-1590752340
  namespace: default
--
    matchLabels:
      controller-uid: 1b028949-6006-4b8a-9732-b8038f9ac420
  template:
    metadata:
      creationTimestamp: null
      labels:
        controller-uid: 1b028949-6006-4b8a-9732-b8038f9ac420
        job-name: alpine-cronjob-1590752340
    spec:
      containers:
[11:40] ~
➤ export controlleruid=(k get jobs -o jsonpath='{.items[2].metadata.labels.controller-uid}{"\n"}')
  echo $controlleruid
1b028949-6006-4b8a-9732-b8038f9ac420
[11:40] ~
➤ k get pod -l controller-uid=$controlleruid                                 vagrant@archlinux
NAME                              READY   STATUS      RESTARTS   AGE
alpine-cronjob-1590752340-g8wrx   0/1     Completed   0          69s
[11:40] ~
➤ k get pod --selector=controller-uid=$controlleruid                         vagrant@archlinux
NAME                              READY   STATUS      RESTARTS   AGE
alpine-cronjob-1590752340-g8wrx   0/1     Completed   0          73s
[11:40] ~
➤ k get pod -l job-name=$job_name                                            vagrant@archlinux
NAME                              READY   STATUS      RESTARTS   AGE
alpine-cronjob-1590752340-g8wrx   0/1     Completed   0          77s
[11:40] ~
➤ k get pod -l job-name=$job_name -o yaml | head -n 6                        vagrant@archlinux
apiVersion: v1
items:
- apiVersion: v1
  kind: Pod
  metadata:
    creationTimestamp: "2020-05-29T11:39:01Z"
[11:40] ~
➤ set pods (k get pods --selector=job-name=$job_name --output=jsonpath='{.items[*].metadata.name}')
  echo $pods
alpine-cronjob-1590752340-g8wrx
[11:40] ~
➤                                                                            vagrant@archlinux
````

Though using job name is very convenient, as just need to list the job.

Note here we display label using `k get pods --selector` unlike  [advanced deployment section](../Deployment/advanced/article.md#deploy-first-version).
But we can ensure it is equivalent and enable to metadata.labels.

````shell script
# <-> $ k get pod  $pod_0_name -o  jsonpath='{.metadata.labels}{"\n"}'
➤ k describe pods nginx-deployment-6b9ccbbbd5-jdpb7 | grep -A 2 Labels                                                                                                        vagrant@archlinuxLabels:       app=nginx-deployment
              pod-template-hash=6b9ccbbbd5
Annotations:  <none>
➤ k get pods nginx-deployment-6b9ccbbbd5-jdpb7 -o yaml | grep -A 5 metadata                                                                                                   vagrant@archlinuxmetadata:
  creationTimestamp: "2020-05-28T19:01:58Z"
  generateName: nginx-deployment-6b9ccbbbd5-
  labels:
    app: nginx-deployment
    pod-template-hash: 6b9ccbbbd5

# <-> And thus equivalent to
➤ k get pods --selector=pod-template-hash=6b9ccbbbd5                                                                                                                          vagrant@archlinuxNAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-6b9ccbbbd5-64kxt   1/1     Running   1          15h
nginx-deployment-6b9ccbbbd5-jdpb7   1/1     Running   1          15h
nginx-deployment-6b9ccbbbd5-qg2k4   1/1     Running   1          15h
[10:29] ~
➤ k get pods -l pod-template-hash=6b9ccbbbd5                                                                                                                                  vagrant@archlinuxNAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-6b9ccbbbd5-64kxt   1/1     Running   1          15h
nginx-deployment-6b9ccbbbd5-jdpb7   1/1     Running   1          15h
nginx-deployment-6b9ccbbbd5-qg2k4   1/1     Running   1          15h
[10:30] ~
````

As for deployment we also have a name cascading:

````shell script
➤ k get cronjob                                                                                                                                                               vagrant@archlinux
NAME             SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
alpine-cronjob   * * * * *   False     1        9s              50s
[11:03] ~
➤ k get jobs                                                                                                                                                                  vagrant@archlinux
NAME                        COMPLETIONS   DURATION   AGE
alpine-cronjob-1590750180   1/1           6s         11s
[11:03] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                READY   STATUS      RESTARTS   AGE
alpine-cronjob-1590750180-4kwxs     0/1     Completed   0          18s
````
OK

### Syntax

In fish unlike bash we need `jsonpath='{.items[*].metadata.name}'` with `'`.

````shell script
[vagrant@archlinux ~]$ kubectl get jobs
NAME                        COMPLETIONS   DURATION   AGE
alpine-cronjob-1590753300   1/1           6s         2m13s
alpine-cronjob-1590753360   1/1           6s         72s
alpine-cronjob-1590753420   1/1           6s         12s
[vagrant@archlinux ~]$ pods=$(kubectl get pods --selector=job-name=alpine-cronjob-1590753360 --output=jsonpath={.items[*].metadata.name})
[vagrant@archlinux ~]$ echo $pods
alpine-cronjob-1590753360-7mnwm
[vagrant@archlinux ~]$ pods=$(kubectl get pods --selector=job-name=alpine-cronjob-1590753360 -o jsonpath={.items[*].metadata.name})
[vagrant@archlinux ~]$ echo $pods
alpine-cronjob-1590753360-7mnwm
[vagrant@archlinux ~]$ exit
exit
[11:58] ~
➤ k get pods --selector=job-name=alpine-cronjob-1590753360 -o jsonpath={.items[*].metadata.name}
fish: No matches for wildcard “jsonpath={.items[*].metadata.name}”. See `help expand`.
k get pods --selector=job-name=alpine-cronjob-1590753360 -o jsonpath={.items[*].metadata.name}
                                                            ^
[11:58] ~
➤ k get pods --selector=job-name=alpine-cronjob-1590753360 -o jsonpath='{.items[*].metadata.name}'
alpine-cronjob-1590753360-7mnwm⏎
````