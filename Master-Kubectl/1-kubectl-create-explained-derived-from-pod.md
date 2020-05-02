# Create ressources deriving from a pod 

## Create pod 

Cf. [kubectl create explained](./0-kubectl-run-explained.md)

````commandline
k run alpine --image alpine --dry-run=client -o yaml -- /bin/sleep 10
````

<details><summary>output</summary>
<p>

````commandline
➤ k run alpine --image alpine --dry-run=client -o yaml -- /bin/sleep 10                                                                                                       vagrant@archlinux
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

</p>
</details>details>


## Create Job

````commandline
k create job alpine-job --image alpine --dry-run=client -o yaml -- /bin/sleep 10
````

<details><summary>output</summary>
<p>

Tips: when copy/pasting ressource select area
````commandline
k create job alpine-job --image alpine --dry-run=client -o yaml -- /bin/sleep 10                                                                                            vagrant@archlinux
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
        - /bin/sleep
        - "10"
        image: alpine
        name: alpine-job
        resources: {}
      restartPolicy: Never
status: {}
````

### Note

`args` becamme `command`.

Cf. https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/
Also command corresponds to `entrypoint` in docker.
> Note: The command field corresponds to entrypoint in some container runtimes. Refer to the Notes below.

Checking `kubectl run/create job` doc:
````commandline
Usage:
  kubectl run NAME --image=image [--env="key=value"] [--port=port] [--dry-run=server|client] [--overrides=inline-json]
[--command] -- [COMMAND] [args...] [options]

Usage:
  kubectl create job NAME --image=image [--from=cronjob/name] -- [COMMAND] [args...] [flags] [options]
````

So:
- create a pod with args (initial case)
````commandline
k run alpine --image alpine --dry-run=client -o yaml -- /bin/sleep 10
````
- creates a pod with a command
````commandline
k run alpine --image alpine --dry-run=client -o yaml --command /bin/sleep 10
````
- creates a pod with a command and args 
````commandline
k run alpine --image alpine --dry-run=client -o yaml --command /bin/sleep -- args 10
````

Whereas  
- create a job with command (initial case)
````commandline
k create job alpine-job --image alpine --dry-run=client -o yaml -- /bin/sleep 10 
````
- create a job with a command args
````commandline
k create job alpine-job --image alpine --dry-run=client -o yaml -- /bin/sleep args 10
````       

Given `create a pod with args (initial case)`, what we give after is always an args.
Thus it should be in CLI doc? [TOFIX]

````commandline
  kubectl run NAME --image=image [--env="key=value"] [--port=port] [--dry-run=server|client] [--overrides=inline-json]
[--command] -- [ARGS] [options]
````

Also:
Yaml syntax can confuse but command is at same level as image.

</p>
</details>

## Create a CronJob

Cron synthax; http://www.nncron.ru/help/EN/working/cron-format.htm

````commandline
k create cronjob alpine-cronjob --image alpine  --schedule="* * * * *" --dry-run=client -o yaml -- /bin/sleep 30 
````

<details><summary>output</summary>
<p>

````commandline
➤ k create cronjob alpine-cronjob --image alpine  --schedule="* * * * *" --dry-run=client -o yaml -- /bin/sleep 30                               
                                                                                                                                                 
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

If creating it:

````commandline
[18:19] ~                                                                                                                          
➤ k create cronjob alpine-cronjob --image alpine  --schedule="* * * * *" -- /bin/sleep 30                                          
cronjob.batch/alpine-cronjob created                                                                                               
[18:20] ~                                                                                                                          
➤ k get cronjob                                                                                                                    
NAME             SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE                                                                
alpine-cronjob   * * * * *   False     0        <none>          9s                                                                 
[18:20] ~                                                                                                                          
➤ k get jobs                                                                                                                       
No resources found in default namespace.                                                                                           
[18:20] ~                                                                                                                                                                                                                                                                                                                                    
➤ k get cronjob                                                                                                                    
NAME             SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE                                                                
alpine-cronjob   * * * * *   False     1        11s             66s                                                                
[18:21] ~                                                                                                                          
➤ k get jobs                                                                                                                       
NAME                        COMPLETIONS   DURATION   AGE                                                                           
alpine-cronjob-1588443660   0/1           12s        12s                                                                           
[18:21] ~                                                                                                                            
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                 READY   STATUS    RESTARTS   AGE
alpine-cronjob-1588443660-l55x6      1/1     Running   0          21s     
➤ k get cronjob                                                                                                                                                               vagrant@archlinux
NAME             SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
alpine-cronjob   * * * * *   False     0        45s             4m40s
[18:24] ~
➤ k get jobs                                                                                                                                                                  vagrant@archlinux
NAME                        COMPLETIONS   DURATION   AGE
alpine-cronjob-1588443720   1/1           37s        2m43s
alpine-cronjob-1588443780   1/1           35s        112s
alpine-cronjob-1588443840   1/1           34s        52s
[18:24] ~
[18:24] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                 READY   STATUS              RESTARTS   AGE
alpine-cronjob-1588443720-rqcl5      0/1     Completed           0          2m55s
alpine-cronjob-1588443780-jngfn      0/1     Completed           0          2m4s
alpine-cronjob-1588443840-fzppm      0/1     Completed           0          64s
alpine-cronjob-1588443900-xjmk5      0/1     ContainerCreating   0          4s                                                       
````

</p>
</details>details>

## Create a replica set

It is not possible to create a replicaset through `kubectl create`.
So have to use `kubectl create -f`, where file provided is any manifest.

From this [doc](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/) I will create a `rs` manifest.

````commandline
echo '
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
k create -f alpine-rs.yaml # --dry-run=client
````

<details><summary>output</summary>
<p>

````commandline
➤ k create -f alpine-rs.yaml # --dry-run=client                                                                                                                               vagrant@archlinux
replicaset.apps/alpine-rs created
[16:52] ~
➤ k get rs                                                                                                                                                                    vagrant@archlinux
NAME        DESIRED   CURRENT   READY   AGE
alpine-rs   3         3         0       5s
[16:52] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME              READY   STATUS    RESTARTS   AGE
alpine-rs-47s7l   1/1     Running   0          12s
alpine-rs-cgbpd   1/1     Running   0          12s
alpine-rs-rxmmq   1/1     Running   0          12s
````

</p>
</details>details>

If I create manually a pod with label: `app: rssample`

````commandline
k run alpine-manual --image alpine  --labels="app=rssample" -- /bin/sleep 60
````

it is immediatly terminated

````commandline
➤ k run alpine-manual --image alpine  --labels="app=rssample" -- /bin/sleep 60                                                                                                vagrant@archlinux
pod/alpine-manual created
[16:59] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME              READY   STATUS        RESTARTS   AGE
alpine-manual     0/1     Terminating   0          3s
alpine-rs-47s7l   1/1     Running       0          6m42s
alpine-rs-cgbpd   1/1     Running       0          6m42s
alpine-rs-rxmmq   1/1     Running       0          6m42s

➤ k delete rs alpine-rs                                                                                                                                                       vagrant@archlinux
replicaset.apps "alpine-rs" deleted
````

Replicaset replaces ReplicationController.

From: https://kubernetes.io/docs/concepts/workloads/controllers/replicationcontroller/
> Note: A Deployment that configures a ReplicaSet is now the recommended way to set up replication.

Note OpenShift `dc` creates a `rc`.

## Create deployment 

````commandline
k create deployment alpine-deployment --image=alpine --dry-run=client -o yaml 
````

We can not give a command directly and `-- /bin/sleep 3600`, is ignored.
When looking at `k create deployment -h` and `k create job -h`, we see it is expected.

<details><summary>output</summary>
<p>

````commandline
➤ k create deployment alpine-deployment --image=alpine --dry-run=client -o yaml                                                                                               vagrant@archlinux
apiVersion: apps/v1
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

</p>
</details>details>

Note `--replicas` does not exist and will remove the `dry-run`. We can use `k scale`.

Using it 

````commandline
➤ k create deployment alpine-deployment --image=alpine                                                                                                                        vagrant@archlinux
deployment.apps/alpine-deployment created
[17:33] ~
➤ k get deployment                                                                                                                                                            vagrant@archlinux
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
alpine-deployment   0/1     1            0           8s
[17:33] ~
➤ k get rs                                                                                                                                                                    vagrant@archlinux
NAME                           DESIRED   CURRENT   READY   AGE
alpine-deployment-585dcccf5b   1         1         0       17s
[17:33] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                 READY   STATUS             RESTARTS   AGE
alpine-deployment-585dcccf5b-f9h4z   0/1     CrashLoopBackOff   1          22s
````

It is in `CrashLoopBackOff` because there is no sleep.

Adding a sleep:

````commandline
k delete deployment alpine-deployment 
k create deployment alpine-deployment --image=alpine --dry-run=client -o yaml > out.txt
# Changing replicas and command 
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
        - /bin/sleep
        - "3600"
        resources: {}
status: {}' > alpine-deployment.yaml
k create -f alpine-deployment.yaml
````

Output is

````commandline
➤ k create -f alpine-deployment.yaml                                                                                                                                          vagrant@archlinux
deployment.apps/alpine-deployment created
[17:44] ~
➤ k get deployments                                                                                                                                                           vagrant@archlinux
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
alpine-deployment   3/3     3            3           17s
[17:44] ~
➤ k get rs                                                                                                                                                                    vagrant@archlinux
NAME                           DESIRED   CURRENT   READY   AGE
alpine-deployment-5d556b4864   3         3         3       21s
[17:44] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinux
NAME                                 READY   STATUS    RESTARTS   AGE
alpine-deployment-5d556b4864-fvhz6   1/1     Running   0          24s
alpine-deployment-5d556b4864-jdbvp   1/1     Running   0          24s
alpine-deployment-5d556b4864-xzg9p   1/1     Running   0          24s
````
Notice generated naming cascading.




