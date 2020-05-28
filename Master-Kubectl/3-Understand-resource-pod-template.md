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