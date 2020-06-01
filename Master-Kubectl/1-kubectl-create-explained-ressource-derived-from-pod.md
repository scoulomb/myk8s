[previous-section](0-kubectl-run-explained.md)

# Create resources deriving from a pod 

## Create pod 

Cf. [kubectl run explained](./0-kubectl-run-explained.md)

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
Tips: when copy/pasting from terminal grab area

</p>
</details>

We can see that this created in the manifest the `spec.containers.args` field with `/bin/sleep` and `10`.
Also, YAML syntax can confuse but args is at same level as image.

<details><summary>Before 1.18 version</summary>
<p>
This is the way to do  from `1.18`, prior it will create a deployment (as default `restartPolicy` is always and based on [this doc](./0-kubectl-run-explained.md#doc-confirming-behavior) as shown in [previous step](./0-kubectl-run-explained.md#version-116).


To create a pod before 1.18 (removing client arg from dry-run):

````buildoutcfg
sudo kubectl run alpine --image alpine --restart=Never --dry-run -o yaml -- /bin/sleep 10 
````
Based on restart it creates apod as shown in [this doc](./0-kubectl-run-explained.md#doc-confirming-behavior) 

Or with the generator as shown previously if we want `Always` restart policy as shown in [previous doc](=./0-kubectl-run-explained.md#doc-confirming-behavior) to be strictly equivalent.

Next of the section was tested with `1.18` but except removal of `dry-run` argument no change is expected in older version.

</p>
</details>

However I recommend for pod to use `restart=Never` thus:

````commandline
k run alpine --image alpine --restart=Never --dry-run=client -o yaml -- /bin/sleep 10
````

<!--

````
sylvain@sylvain-hp:~$ sudo -i
[sudo] password for sylvain: 
root@sylvain-hp:~# alias k='kubectl'
root@sylvain-hp:~# k run alpine --image alpine --restart=Never --dry-run=client -o yaml -- /bin/sleep 10
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

root@sylvain-hp:~# k version
Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.3", GitCommit:"2e7996e3e2712684bc73f0dec0200d64eec7fe40", GitTreeState:"clean", BuildDate:"2020-05-20T12:52:00Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.2", GitCommit:"52c56ce7a8272c798dbc29846288d7cd9fbae032", GitTreeState:"clean", BuildDate:"2020-04-16T11:48:36Z", GoVersion:"go1.13.9", Compiler:"gc", Platform:"linux/amd64"}

````
Later ubuntu@hp had 1.18 while vagrant Archlinux had <1.18.
-->


## Create Job

````commandline
k create job alpine-job --image alpine --dry-run=client -o yaml -- /bin/sleep 10
````

<details><summary>output</summary>
<p>

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

</p>
</details>

We can see that this created in the manifest the `spec.containers.command` field with `/bin/sleep` and `10`.


## Note on args and command

### What is it?

Cf. https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/
> Note: The command field corresponds to entrypoint in some container runtimes. Refer to the Notes below.

Thus:
- Docker `ENTRYPOINT` <=>  k8s `command` 
- Docker `CMD` <=> k8s `args`

`ENTRYPOINT` and `CMD` can be defined in image and be overridden by k8s.
It is clearly documented here in [k8s documentation](https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#notes).

````xhtml
> This table summarizes the field names used by Docker and Kubernetes.
> 
> Description	                        Docker field name	     Kubernetes field name
> The command run by the container	    Entrypoint	             command
> The arguments passed to the command	Cmd	                     args
> 
> When you override the default Entrypoint and Cmd, these rules apply:
> 
> If you do not supply command or args for a Container, the defaults defined in the Docker image are used.
> If you supply a command but no args for a Container, only the supplied command is used. The default EntryPoint and the default Cmd defined in the Docker image are ignored.
> If you supply only args for a Container, the default Entrypoint defined in the Docker image is run with the args that you supplied.
> If you supply a command and args, the default Entrypoint and the default Cmd defined in the Docker image are ignored. Your command is run with your args.

````

In Docker CLI it is also possible to oveeride docker `ENTRYPOINY` and `CMD`:

````commandline
docker run --entrypoint "/bin/sleep"  alpine 5
````
And as stated in this [medium article](https://medium.com/@oprearocks/how-to-properly-override-the-entrypoint-using-docker-run-2e081e5feb9d)
> There is something a bit counter-intuitive here and if you take a good look at the example commands on the documentation page, you’ll see that the arguments are being passed after the image name.

### Discrepancy between `k run` and `k create`

- When using `k run` it created `args`
- When using `k create` it created `command`.

Checking `kubectl run -h`:

````commandline
      --command=false: If true and extra arguments are present, use them as the 'command' field in the container, rather
than the 'args' field which is the default.

Usage:
  kubectl run NAME --image=image [--env="key=value"] [--port=port] [--dry-run=server|client] [--overrides=inline-json]
[--command] -- [COMMAND] [args...] [options]
````

And `kubectl create job -h`:
````commandline
Usage:
  kubectl create job NAME --image=image [--from=cronjob/name] -- [COMMAND] [args...] [flags] [options]
````

As a conclusion 

- create a pod with args (initial case)
````commandline
k run alpine --image alpine --dry-run=client -o yaml -- /bin/sleep 10
````

- But we can a create pod with command using `--command`

````commandlin
k run alpine --image alpine --dry-run=client -o yaml --command /bin/sleep -- 10
````

<details><summary>output</summary>
<p>

````commandline
➤ k run alpine --image alpine --dry-run=client -o yaml --command /bin/sleep -- 10                                                                                             vagrant@archlinux
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: alpine
  name: alpine
spec:
  containers:
  - command:
    - /bin/sleep
    - "10"
    image: alpine
    name: alpine
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
````

What is after `--` become also command and not args. If doing `--args` it will not create args!

</p>
</details>

We can not mix command and args with kubectl.


- create a job with command (initial case)
````commandline
k create job alpine-job --image alpine --dry-run=client -o yaml -- /bin/sleep 10 
````

I can only generate `command` with `kubectl create job`, not args.

Note I can  create job with command and args with `k create -f`

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
        - /bin/sleep
        args:
        - "10"
        image: alpine
        name: alpine-job
        resources: {}
      restartPolicy: Never' > job_with_command_args.yaml

k create -f job_with_command_args.yaml
````

<details><summary>output</summary>
<p>

````commandline
➤ k create -f job_with_command_args.yaml
job.batch/alpine-job created
[21:19] ~
➤ k get jobs                        vagrant@archlinuxNAME         COMPLETIONS   DURATION   AGE
alpine-job   0/1           4s         4s
[21:19] ~
➤ k get pods                        vagrant@archlinuxNAME               READY   STATUS    RESTARTS   AGE
alpine-job-9gd5m   1/1     Running   0          10s
[21:19] ~
➤ k get pods                        vagrant@archlinuxNAME               READY   STATUS      RESTARTS   AGEalpine-job-9gd5m   0/1     Completed   0          28s[21:19] ~
➤ k get jobs                        vagrant@archlinuxNAME         COMPLETIONS   DURATION   AGE
alpine-job   1/1           14s        46s
[21:19] ~
````

</details>
</p>

I found  `[COMMAND] [args...]` in doc confusing because I would expect:
- `[COMMAND]` to match k8s manifest `spec.containers.command`,
- `[args]` to match k8s manifest `spec.containers.args`
And it is actually
- `[COMMAND]` seems to match k8s manifest `spec.containers.command[0]`
- `[args]` seems to match k8s manifest `spec.containers.command[1..N]`

For pod several interpretations are possible.

## Create a CronJob

Cron synthax [reminder](http://www.nncron.ru/help/EN/working/cron-format.htm).
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
</details>

## Create a replica set

It is not possible to create a `replicaset` through `kubectl create`.
So have to use `kubectl create -f`, where a file provided as any manifest.

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

it is terminated as it is "captured" by the `replicaset`.

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

Note OpenShift `DeploymentConfig`creates a `ReplicationController`.

## Create deployment 

````commandline
k create deployment alpine-deployment --image=alpine --dry-run=client -o yaml 
````

We can not give a command directly and `-- /bin/sleep 3600`, is ignored.
When looking at `k create deployment -h` and `k create job -h`, we see it is expected. Deployment does not take a `command` or `args` directly (it can take template).

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
</details>

Note `--replicas` does not exist. We can use `k scale`.

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

It is in `CrashLoopBackOff` because alpine has probably define a short command.
Thus is not "Always" running. 
We will study this in [next section](2-kubectl-create-explained-ressource-derived-from-pod-appendices.md#Explanation-why-we-have-CrashLoppBackOff)

Adding a sleep will avoid the `CrashLoopBackOff` until sleep ends !

<details><summary>output</summary>
<p>

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
        - "25"
        resources: {}
status: {}' > alpine-deployment.yaml
k create -f alpine-deployment.yaml
````

Output is

````commandline
[23:10] ~
➤ k get deployments                                                                                                                                                           vagrant@archlinuxNAME                READY   UP-TO-DATE   AVAILABLE   AGE
alpine-deployment   3/3     3            3           21s
[23:10] ~
➤ k get rs                                                                                                                                                                    vagrant@archlinuxNAME                           DESIRED   CURRENT   READY   AGE
alpine-deployment-7cfd9f6756   3         3         3       27s
[23:10] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                                 READY   STATUS    RESTARTS   AGE
alpine-deployment-7cfd9f6756-8r64g   1/1     Running   0          31s
alpine-deployment-7cfd9f6756-hmb92   1/1     Running   0          31s
alpine-deployment-7cfd9f6756-xkxck   1/1     Running   0          31s
[23:10] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                                 READY   STATUS    RESTARTS   AGE
alpine-deployment-7cfd9f6756-8r64g   1/1     Running   1          42s
alpine-deployment-7cfd9f6756-hmb92   1/1     Running   1          42s
alpine-deployment-7cfd9f6756-xkxck   1/1     Running   1          42s
[23:10] ~
➤                                                                                                                                                                             vagrant@archlinux[23:11] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                                 READY   STATUS             RESTARTS   AGE
alpine-deployment-7cfd9f6756-8r64g   0/1     CrashLoopBackOff   1          73s
alpine-deployment-7cfd9f6756-hmb92   0/1     Completed          1          73s
alpine-deployment-7cfd9f6756-xkxck   0/1     Completed          1          73s
[23:11] ~
➤ k get pods                                                                                                                                                                  vagrant@archlinuxNAME                                 READY   STATUS    RESTARTS   AGE
alpine-deployment-7cfd9f6756-8r64g   1/1     Running   2          91s
alpine-deployment-7cfd9f6756-hmb92   1/1     Running   2          91s
alpine-deployment-7cfd9f6756-xkxck   1/1     Running   2          91s
[23:11] ~
````
Notice generated naming cascading.

</p>
</details>

[next section](2-kubectl-create-explained-ressource-derived-from-pod-appendices.md#Explanation-why-we-have-CrashLoppBackOff)
 
