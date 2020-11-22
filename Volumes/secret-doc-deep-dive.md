# Note on Kubernetes secrets 

## Secrets consumed as environment variable and secret update

I will start from this use-case

https://kubernetes.io/docs/concepts/configuration/secret/#use-case-as-container-environment-variables
and using: https://github.com/scoulomb/docker-doctor

````shell script
echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin123' > mysecret.yaml

kubectl apply -f mysecret.yaml

echo 'apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
spec:
  containers:
    - name: test-container
      image: registry.hub.docker.com/scoulomb/docker-doctor:dev
      envFrom:
      - secretRef:
          name: mysecret
  restartPolicy: Always' > mypod.yaml
kubectl delete -f mypod.yaml
kubectl apply -f mypod.yaml


sudo kubectl exec -it  secret-test-pod -- env

````

Output is

````shell script
root@sylvain-hp:/home/sylvain# sudo kubectl exec -it  secret-test-pod -- env | grep admin
PASSWORD=admin123
USERNAME=admin
````

<!-- I use default docker ENTRYPOINT (k8s command) in image, so no need to define it here 
Working the same as described in docker-doctor repo--> 

Let's say I update my secret, what will happen here?


````shell script
echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin456' > mysecret.yaml

kubectl apply -f mysecret.yaml
````


and running 

````shell script
sudo kubectl exec -it  secret-test-pod -- env | grep admin
````

output is 

````shell script
root@sylvain-hp:/home/sylvain# sudo kubectl exec -it  secret-test-pod -- env | grep admin
PASSWORD=admin123
USERNAME=admin
````

It is not updated.
I will not recreate the pod but force the kubelet (it is not a pod controller) to restart the container.
```shell script
docker kill $(docker ps | grep "k8s_test-container_secret-test-pod_default_" | awk {'print $1'})
````

Note restart policy needs to be set to Always.


And password was now updated 

```shell script
root@sylvain-hp:/home/sylvain# sudo kubectl exec -it  secret-test-pod -- env | grep admin
USERNAME=admin
PASSWORD=admin456
````

As a consequence secret consumed as environment var needs container restart to be updated.

It is exactly the same problem raised for service discovery by [environment variable](../Services/service_deep_dive.md#svc-discovery-by-environment-variable-or-dns-within-a-pod).



## Secrets consumed as environment variable and secret update but through a job 

https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md#create-a-cronjob

````shell script
echo "apiVersion: batch/v1beta1                                                                                                                        
kind: CronJob                                                                                                                                    
metadata:                                                                                                                                        
  creationTimestamp: null                                                                                                                        
  name: dockerdoc-cronjob                                                                                                                           
spec:                                                                                                                                            
  jobTemplate:                                                                                                                                   
    metadata:                                                                                                                                                                                                                                                     
      name: cronjob                                                                                                                       
    spec:                                                                                                                                        
      template:                                                                                                                                  
        metadata:                                                                                                                                
          creationTimestamp: null                                                                                                                
        spec:
          containers:
            - name: test-container
              image: registry.hub.docker.com/scoulomb/docker-doctor:dev
              envFrom:
              - secretRef:
                  name: mysecret
          restartPolicy: 'OnFailure'                                                                                                       
  schedule: '* * * * *'" > cj.yaml

echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin123' > mysecret.yaml

kubectl apply -f mysecret.yaml
kubectl apply -f cj.yaml

sleep 90

echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin456' > mysecret.yaml
kubectl apply -f mysecret.yaml

````

Then taking most recent and oldest pods

````shell script
root@sylvain-hp:/home/sylvain# kubectl get po | grep dockerdoc-cronjob-
dockerdoc-cronjob-1605293760-4xq5n        1/1     Running            0          28m
dockerdoc-cronjob-1605293820-cq5h6        1/1     Running            0          27m
[...]
dockerdoc-cronjob-1605295440-58bkk        1/1     Running            0          57s
````

````shell script
sudo kubectl exec -it  dockerdoc-cronjob-1605293760-4xq5n -- env | grep admin
sudo kubectl exec -it  dockerdoc-cronjob-1605295440-58bkk -- env | grep admin

````

output is 

````shell script
root@sylvain-hp:/home/sylvain# sudo kubectl exec -it  dockerdoc-cronjob-1605293760-4xq5n -- env | grep admin
PASSWORD=admin123
USERNAME=admin
root@sylvain-hp:/home/sylvain# sudo kubectl exec -it  dockerdoc-cronjob-1605295440-58bkk -- env | grep admin
PASSWORD=admin456
USERNAME=admin
````

So it takes the environment variable at pod definition.

and clean

````shell script
kubectl delete cj dockerdoc-cronjob
````

With kubectl it also clean the pod :)

## Do we need to forward declare the secret?

Assume we do not know the secret yet ?
We would need to:
- 1/ Define empty secret along the cj. cj consumed secrets as environment var
- 2/ Then define the actual secret 

Given the observation made in section [above](#secrets-consumed-as-environment-variable-and-secret-update-but-through-a-job)
It would work but only in this order otherwise we would overwrite the secret.
And the actual secret has to be defined before the pod starts.

<!-- for direct pod definition we could not do pod + empty secret and then coorect secret, we would have to do define correct secret before the pod then it would override good secret!-->

Then then since the cj consumed secret as environment var it can be sue by the application. What we when we call `env`.
<!-- nameserver PR#68 -->
Assume you want to configure (non-regression) job via Jenkins, you would use Jenkins credentials feature to perform this operation
See: https://stackoverflow.com/questions/43026637/how-to-get-username-password-stored-in-jenkins-credentials-separately-in-jenkins

It would look like this: you would get a secret manifest from a Openshift template/helm chart: 
````shell script
withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'USER', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']]) {
    sh "./path/to/oc process --local --output='yaml' -f kubernetes/templates/non-regression-secret-variables.yaml -p USERNAME='$USERNAME' -p PASSWORD='$PASSWORD' > ${secret_filename}"
}
````

Note: This require to create credentials in Jenkins.
Go to folder Global credentials: https://<jenkins-instance>/job/<project-name>/credentials/store/folder/domain/_/
Here use  Add Credentials, Kind is username and password 
Ensure ID matches the one in Jenkins file.
Other secret you could have is:
- Dockerhub (or equivalent) credentials
- and for `oc` or `helm` client (kind is secret text if you use a TOKEN).

Then perform the two steps 1/ 2/.

Do we need to define an empty secret?


If we do

````shell script

echo 'apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod-with-secret-which-is-not-existing
spec:
  containers:
    - name: test-container
      image: registry.hub.docker.com/scoulomb/docker-doctor:dev
      envFrom:
      - secretRef:
          name: secret-which-is-not-existing
  restartPolicy: Always' > mypod.yaml

kubectl apply -f mypod.yaml
````

We can create the pod but 


````shell script
root@sylvain-hp:/home/sylvain# kubectl describe po secret-test-pod-with-secret-which-is-not-existing | grep -A 5 Events
Events:
  Type     Reason     Age               From                 Message
  ----     ------     ----              ----                 -------
  Normal   Scheduled  <unknown>         default-scheduler    Successfully assigned default/secret-test-pod-with-secret-which-is-not-existing to sylvain-hp
  Normal   Pulled     3s (x6 over 44s)  kubelet, sylvain-hp  Container image "registry.hub.docker.com/scoulomb/docker-doctor:dev" already present on machine
  Warning  Failed     3s (x6 over 44s)  kubelet, sylvain-hp  Error: secret "secret-which-is-not-existing" not found
````

if we do 

````shell script
echo 'apiVersion: v1
kind: Secret
metadata:
  name: secret-which-is-not-existing
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin456' > mysecret.yaml
kubectl apply -f mysecret.yaml
````

it will be autofixed by the Kubelet <3

````shell script
root@sylvain-hp:/home/sylvain#  kubectl describe po secret-test-pod-with-secret-which-is-not-existing | grep -A 15 Events
Events:
  Type     Reason     Age                   From                 Message
  ----     ------     ----                  ----                 -------
  Normal   Scheduled  <unknown>             default-scheduler    Successfully assigned default/secret-test-pod-with-secret-which-is-not-existing to sylvain-hp
  Warning  Failed     58s (x10 over 2m36s)  kubelet, sylvain-hp  Error: secret "secret-which-is-not-existing" not found
  Normal   Pulled     43s (x11 over 2m36s)  kubelet, sylvain-hp  Container image "registry.hub.docker.com/scoulomb/docker-doctor:dev" already present on machine
  Normal   Created    43s                   kubelet, sylvain-hp  Created container test-container
  Normal   Started    43s                   kubelet, sylvain-hp  Started container test-container
````

And this is confirmed by the doc here: https://kubernetes.io/docs/concepts/configuration/secret/#secret-and-pod-lifetime-interaction

> When a Pod is created by calling the Kubernetes API, there is no check if a referenced secret exists. Once a Pod is scheduled, the kubelet will try to fetch the secret value. If the secret cannot be fetched because it does not exist or because of a temporary lack of connection to the API server, the kubelet will periodically retry. It will report an event about the Pod explaining the reason it is not started yet. Once the secret is fetched, the kubelet will create and mount a volume containing it. None of the Pod's containers will start until all the Pod's volumes are mounted.

**Secret forward declaration enables to start the non-regression container even if not defined, but can make investigation harder in case container start without secrets as environment variable will not be there and can make application malfunction.**
It depends on your use-case.

## We can consume the secret as volumes.
 
Why? **It will enable secret update without restarting the container**


<!-- for non regression use-case intent is limited, so I decided to actually leave untouched, and need change in code
it would be needed if we want to update the secret while a non reg is running, it is useless -->

I will prove it!

It is explained here in the doc: https://kubernetes.io/docs/concepts/configuration/secret/#mounted-secrets-are-updated-automatically

> When a secret currently consumed in a volume is updated, projected keys are eventually updated as well. The kubelet checks whether the mounted secret is fresh on every periodic sync. However, the kubelet uses its local cache for getting the current value of the Secret. The type of the cache is configurable using the ConfigMapAndSecretChangeDetectionStrategy field in the KubeletConfiguration struct. A Secret can be either propagated by watch (default), ttl-based, or simply redirecting all requests directly to the API server. As a result, the total delay from the moment when the Secret is updated to the moment when new keys are projected to the Pod can be as long as the kubelet sync period + cache propagation delay, where the cache propagation delay depends on the chosen cache type (it equals to watch propagation delay, ttl of cache, or zero correspondingly).
> Note: A container using a Secret as a subPath volume mount will not receive Secret updates


Flow will be:
- we consume secret as a volume,
- and create environment var with volume path, 
- then client code would have to get the volume value using the path in environment var

Here are features used:

````shell script
kubectl explain pod.spec.volumes
kubectl explain pod.spec.containers.volumeMounts
````

Let's do it

````shell script
echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin123' > mysecret.yaml

kubectl apply -f mysecret.yaml

echo 'apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
spec:
  containers:
    - name: test-container
      image: registry.hub.docker.com/scoulomb/docker-doctor:dev 
      env:
      - name: USERNAME
        value: /etc/secrets/mysecret/USERNAME
      - name: PASSWORD
        value: /etc/secrets/mysecret/PASSWORD
      volumeMounts:
      - name: mysecretvol
        mountPath: "/etc/secrets/mysecret"
  restartPolicy: Always
  volumes:
  - name: mysecretvol
    secret:
      secretName: mysecret'  > mypod.yaml

kubectl delete -f mypod.yaml
kubectl apply -f mypod.yaml

sudo kubectl exec -it  secret-test-pod -- cat /etc/secrets/mysecret/USERNAME 
# we need a shell for ";" and variable expansion as explained here: https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-d.md
sudo kubectl exec -it  secret-test-pod -- /bin/sh -c 'echo "u/p" && cat /etc/secrets/mysecret/USERNAME && echo " / " && cat /etc/secrets/mysecret/PASSWORD'
sudo kubectl exec -it  secret-test-pod -- /bin/sh -c 'cat $(echo $USERNAME)'
sudo kubectl exec -it  secret-test-pod -- /bin/sh -c 'cat $(echo $PASSWORD)'

````

Output is

````shell script
root@sylvain-hp:/home/sylvain# sudo kubectl exec -it  secret-test-pod -- /bin/sh -c 'echo "u/p" && cat /etc/secrets/mysecret/USERNAME && echo " / " && cat /etc/secrets/mysecret/PASSWORD'
u/p
admin /
admin123
root@sylvain-hp:/home/sylvain# sudo kubectl exec -it  secret-test-pod -- /bin/sh -c 'cat $(echo $USERNAME)'
admin
root@sylvain-hp:/home/sylvain# sudo kubectl exec -it  secret-test-pod -- /bin/sh -c 'cat $(echo $PASSWORD)'
admin123
````

Let's say I update my secret, what will happen here?


````shell script
echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin456' > mysecret.yaml

kubectl apply -f mysecret.yaml
````


and running 

````shell script
sudo kubectl exec -it  secret-test-pod -- /bin/sh -c 'cat $(echo $PASSWORD)'
````

output is 

````shell script
adminroot@sylvain-hp:/home/sylvain# sudo kubectl exec -it  secret-test-pod -- /bin/sh -c 'cat $(echo $PASSWORD)'
admin456
````

Password **is** updated without container restart.
<!-- similar to cm -->

<!-- do not perform update on nr code, kubernetes -->

Here we had seen different consumption mode: https://github.com/scoulomb/myk8s/blob/master/Volumes/volume4question.md#4-configmap-consumption


Equivalent with our section and k8s doc
- [Secrets consumed as environment variable and secret update](#secrets-consumed-as-environment-variable-and-secret-update-but-through-a-job)
    - https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-environment-variables
    - and subpart https://kubernetes.io/docs/concepts/configuration/secret/#consuming-secret-values-from-environment-variables
    - and subpart my pr#25027
- [We can consume the secret as volumes](#we-can-consume-the-secret-as-volumes)
    - https://kubernetes.io/docs/concepts/configuration/secret/#consuming-secret-values-from-volumes.
    where we have path from env var.
    and show that  https://kubernetes.io/docs/concepts/configuration/secret/#mounted-secrets-are-updated-automatically
    
For env var we could say in a PR
````shell script

### v1
title: Consumed secret values from environment variables are not updated automatically
When a secret value currently consumed from environment variable is updated, container's environment variable will not be updated.
Environment variable will be updated if the container is restarted by the kubelet.

### v2
title: Consumed secret values from environment variables are not updated automatically
If a container already consumed a secret value from environment variable, a secret update will not cascade update to the  containrer.    

Environment variable will be updated if the container is restarted by the kubelet.

=> biy envFrom did not try but pretty sure key are also not updated, and would be present if kubelet is restart 
=> already because when not defined error as seen here

### v3 (pr initial version)
title:  Environment variables are not updated after a secret update

If a container already consumed a secret in an environment variable, secret update will not cascade update to the container.
But if the Kubelet restarts the container, secret update will be available.
=> if pod deleted and restarted it is obvious we have the update  
````

<!-- concluded;
when doing pr in my k8s could have one update branch we rebase everytime OK-->
PR => https://github.com/kubernetes/website/pull/25027


## Note on ConfigMap

ConfigMap would work the same way (not tested).

## What would be the alternative to Configmap or secret

Rather than using a ConfigMap or Secret (less true if we encrypt https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/).
We could use OpenShift template or Helm values in the deployment/deployment config itself (note secret/cm can also be parametrized).
<!-- and did it -->
This would be useful for a configuration depending on the environment.
Rather than having a ConfigMap we could instantiate a template for a specific environment.
Also a change of configuration would imply a new template load which is less dangerous (evil) than a ConfigMap change.

## Parallel

We had made the parallel with service discovery by [environment variable](../Services/service_deep_dive.md#svc-discovery-by-environment-variable-or-dns-within-a-pod).
Environment var discovery as ordering and update issue, same as when consuming secret as environment var.

See https://kubernetes.io/docs/concepts/services-networking/service/
>  Note:
>  When you have a Pod that needs to access a Service, and you are using the environment variable method to publish the port and cluster IP to the client Pods, you must create the Service before the client Pods come into existence. Otherwise, those client Pods won't have their environment variables populated.
>  If you only use DNS to discover the cluster IP for a Service, you don't need to worry about this ordering issue.

When using service DNS we can use a combination of environment var and DNS. 
<! described here originally: /browse/myk8s/current.md --> 

Here are several options:
- 1/ Template parameter where
    - A/ the hostname template value can be “service-name” in all namespace, because we rely on the fact services are in same namespace
    - B/ or specialized per namespace myservice.namespace.svc.
    <!-- not sure on dot -->
- 2/ We can eventually hard code a SERVICE_NAME environment var in the template (it is not a template parameter) if we rely on same hypothesis as A

This may be better than hardcoding service name (DNS) in the code.
When we say service we can also use route.

It would not be a good idea to create environment var with the same name as the one coming from the service name.

````shell script
ssh sylvain@109.29.148.109 
sudo minikube start --vm-driver=none
sudo su 
kubectl run anotherimage --image=registry.hub.docker.com/scoulomb/docker-doctor:dev
kubectl expose pod anotherimage --port 8080
echo 'apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
spec:
  containers:
    - name: test-container
      image: registry.hub.docker.com/scoulomb/docker-doctor:dev
      env:
      - name: USERNAME
        value: scoulomb

  restartPolicy: Always' > mypod.yaml
kubectl delete -f mypod.yaml
kubectl apply -f mypod.yaml
````


Output of 

````shell script
kubectl exec -it  secret-test-pod -- env | grep ANOTHERIMAGE
````

is 

````shell script
root@sylvain-hp:/home/sylvain# kubectl exec -it  secret-test-pod -- env | grep ANOTHERIMAGE
ANOTHERIMAGE_PORT=tcp://10.109.40.234:8080
ANOTHERIMAGE_PORT_8080_TCP_PROTO=tcp
ANOTHERIMAGE_PORT_8080_TCP_PORT=8080
ANOTHERIMAGE_SERVICE_HOST=10.109.40.234
ANOTHERIMAGE_PORT_8080_TCP=tcp://10.109.40.234:8080
ANOTHERIMAGE_PORT_8080_TCP_ADDR=10.109.40.234
ANOTHERIMAGE_SERVICE_PORT=8080
````

what happens if I override `ANOTHERIMAGE_SERVICE_HOST`

````shell script
echo 'apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
spec:
  containers:
    - name: test-container
      image: registry.hub.docker.com/scoulomb/docker-doctor:dev
      env:
      - name: USERNAME
        value: scoulomb
      - name: ANOTHERIMAGE_SERVICE_HOST
        value: mydnstosvc
  restartPolicy: Always' > mypod.yaml
kubectl delete -f mypod.yaml
kubectl apply -f mypod.yaml
````



Output of 

````shell script
kubectl exec -it  secret-test-pod -- env | grep ANOTHERIMAGE
````

is 

````shell script
root@sylvain-hp:/home/sylvain# kubectl exec -it  secret-test-pod -- env | grep ANOTHERIMAGE
ANOTHERIMAGE_SERVICE_HOST=mydnstosvc
ANOTHERIMAGE_PORT_8080_TCP=tcp://10.109.40.234:8080
ANOTHERIMAGE_PORT_8080_TCP_PORT=8080
ANOTHERIMAGE_PORT_8080_TCP_PROTO=tcp
ANOTHERIMAGE_PORT_8080_TCP_ADDR=10.109.40.234
ANOTHERIMAGE_SERVICE_PORT=8080
ANOTHERIMAGE_PORT=tcp://10.109.40.234:8080
````

Therefore variable defined directly takes precedence.
It can be useful to not update teh code is started to use env service discovery and want to switch to option 1 but it is also confusing.

<!-- link secret page and here done STOP CONCLUDE OK -->
<!-- about a comment made which is compliant
Note on service discovery 
Pour les service discovery par environment variable voici la doc de Kubernetes:
https://kubernetes.io/docs/concepts/services-networking/service/#environment-variables, par rapport a la note 
> When you have a Pod that needs to access a Service, and you are using the environment variable method to publish the port and cluster IP to the client Pods, you must create the Service before the client Pods come into existence. Je me demandais si il ne serait pas mieux de faire la discovery par DNS https://kubernetes.io/docs/concepts/services-networking/service/#dns (apres ca pourrait etre une env var qui contient le service DNS name, mais ca serait plus safe, et eviterait un ordre dans les deployments et donc une erreur de connectivite)

private/browse/myk8s/current.md (I recommend to still have environment var pointing to service DNS name.) => proposal 1/
+ [link](../Services/service_deep_dive.md#svc-discovery-by-environment-variable-or-dns-within-a-pod)

And for DNS experiments had seen some case did not work (nslookup tutu.com $DNS_SERVICE_NAME):
https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-docker-bind-dns-use-linux-nameserver-rather-route53/6-use-linux-nameserver.sh#L100
(did not check if cluster issue  with normal svc osef)
-->

## Questions: can we update environment var when not using a secret?
 
(pr#25027 kbhawkey's comment)

Answer is no.

Unlike environment consumed from secret, we will be forced to restart the container (delete the pod more exactly). Therefore we have no risk to have your environment var not updated.

For instance and as a proof

````
echo 'apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
    - name: test-container
      image: registry.hub.docker.com/scoulomb/docker-doctor:dev
      env:
      - name: USERNAME
        value: scoulomb

  restartPolicy: Always' > mypod.yaml
kubectl delete -f mypod.yaml
kubectl apply -f mypod.yaml
````

They if you try to edit via kubectl edit you will have 

````
spec: Forbidden: pod updates may not change fields other than `spec.containers[*].image`, `spec.initContainers[*].image`, `spec.activeDeadlineSeconds` or `spec.tolerations` (only additions to existing tolerations)
````


Same when using the  declarative API which prevents from modifying env var
If we redefine test-pod
````
echo 'apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
    - name: test-container
      image: registry.hub.docker.com/scoulomb/docker-doctor:dev
      env:
      - name: USERNAME
        value: scoulomb2

  restartPolicy: Always' > mypod.yaml

kubectl apply -f mypod.yaml
````

Output is 

```` 
root@sylvain-hp:/home/sylvain# kubectl apply -f mypod.yaml
The Pod "test-pod" is invalid: spec: Forbidden: pod updates may not change fields other than `spec.containers[*].image`, `spec.initContainers[*].image`, `spec.activeDeadlineSeconds` or `spec.tolerations` (only additions to existing tolerations)
  core.PodSpec{
        Volumes:        []core.Volume{{Name: "default-token-69j8q", VolumeSource: core.VolumeSource{Secret: &core.SecretVolumeSource{SecretName: "default-token-69j8q", DefaultMode: &420}}}},         InitContainers: nil,
        Containers: []core.Container{
                {
                        ... // 5 identical fields
                        Ports:   nil,
                        EnvFrom: nil,
                        Env: []core.EnvVar{
                                {
                                        Name:      "USERNAME",
-                                       Value:     "scoulomb2",
+                                       Value:     "scoulomb",
                                        ValueFrom: nil,
                                },
                        },
                        Resources:    core.ResourceRequirements{},
                        VolumeMounts: []core.VolumeMount{{Name: "default-token-69j8q", ReadOnly: true, MountPath: "/var/run/secrets/kubernetes.io/serviceaccount"}},
                        ... // 12 identical fields
                },
        },
        EphemeralContainers: nil,
        RestartPolicy:       "Always",
        ... // 24 identical fields
  }
````

We will have to do 

````
kubectl delete -f mypod.yaml
kubectl apply -f mypod.yaml
````

to have the change.
This is described here:
https://github.com/kubernetes/kubernetes/issues/24913


## Third party solutions for triggering restarts when ConfigMaps and Secrets change
 
(pr#25027 sftim's comment)

> It'd be nice to mention that there are third party solutions for triggering restarts when ConfigMaps and Secrets change.
> Maybe even link to https://github.com/stakater/Reloader (which is an example of one of these). Maybe not. It's just an idea.

In section [Secrets consumed as environment variable and secret update](#secrets-consumed-as-environment-variable-and-secret-update).

If a container already consumed a secret in an environment variable, a secret update will not be seen by the container unless it [container] is restarted. [by the Kubelet]
A pod restarts (which makes the Kubelet starts a new container) will thus also make the update available. 

Note
- Container restart only involves data plane (Kubelet).
- Pod restart involves data and control plane (pod controller/custom operator like Reloader).

<!-- Jiehong comment -->

<details>
  <summary>More details on control plane and data plane</summary>:
- https://kubernetes.io/docs/concepts/overview/components/
- https://kccncna20.sched.com/event/ekAL/inside-kubernetes-ingress-dominik-tornow-cisco (slide 90)

Note that container restart ensure we are running on same node, after pod restart, initial pod is terminated and new pod can be scheduled on a different node. 
</details>

There are third party solutions for triggering Pod restarts when ConfigMaps and Secrets change.
Reloader (https://github.com/stakater/Reloader) is an example of one of these.

This would enable to ensure only only pods with environment variable from updated secrets are running.

For this we needpod created from a deployment. 

 
I will start from this use-case

https://kubernetes.io/docs/concepts/configuration/secret/#use-case-as-container-environment-variables
and using: https://github.com/scoulomb/docker-doctor

<!--
https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md#note-on-args-and-command
-->

````shell script
sudo su 
minikube start --vm-driver=none

echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin123' > mysecret.yaml

kubectl apply -f mysecret.yaml

echo 'apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: mydeployment
  name: mydeployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mydeployment
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: mydeployment
    spec:  
      containers:
        - name: test-container
          image: registry.hub.docker.com/scoulomb/docker-doctor:dev
          envFrom:
          - secretRef:
              name: mysecret
      restartPolicy: Always' > mydeployment.yaml
kubectl delete -f mydeployment.yaml
kubectl apply -f mydeployment.yaml

kubectl get po | grep mydeployment
kubectl exec -it  $(kubectl get po | grep mydeployment | awk '{print $1}') -- env | grep admin

````

Output is

````shell script
root@sylvain-hp:/home/sylvain# kubectl get po | grep mydeployment
mydeployment-7d5d555755-jwmzx                       1/1     Running            0          3m55s
root@sylvain-hp:/home/sylvain# kubectl exec -it  $(kubectl get po | grep mydeployment | awk '{print $1}') -- env | grep admin
USERNAME=admin
PASSWORD=admin123
root@sylvain-hp:/home/sylvain#
````

Let's say I update my secret, what will happen here?


````shell script
echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin456' > mysecret.yaml

kubectl apply -f mysecret.yaml
````


and running 

````shell script
kubectl get po | grep mydeployment
kubectl exec -it  $(kubectl get po | grep mydeployment | awk '{print $1}') -- env | grep admin

````

output is 

````shell script
root@sylvain-hp:/home/sylvain# kubectl get po | grep mydeployment
mydeployment-7d5d555755-jwmzx                       1/1     Running            0          4m42s
root@sylvain-hp:/home/sylvain# kubectl exec -it  $(kubectl get po | grep mydeployment | awk '{print $1}') -- env | grep admin
USERNAME=admin
PASSWORD=admin123
root@sylvain-hp:/home/sylvain#
````

It is not updated.

I will now deploy reloader

````shell script
kubectl apply -f https://raw.githubusercontent.com/stakater/Reloader/master/deployments/kubernetes/reloader.yaml
````


And update my deployment with annotation `secret.reloader.stakater.com/reload`.


````shell script
echo 'apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    secret.reloader.stakater.com/reload: "mysecret"
  creationTimestamp: null
  labels:
    app: mydeployment
  name: mydeployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mydeployment
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: mydeployment
    spec:  
      containers:
        - name: test-container
          image: registry.hub.docker.com/scoulomb/docker-doctor:dev
          envFrom:
          - secretRef:
              name: mysecret
      restartPolicy: Always' > mydeployment.yaml

kubectl apply -f mydeployment.yaml

kubectl get po | grep mydeployment
kubectl exec -it  $(kubectl get po | grep mydeployment | awk '{print $1}') -- env | grep admin
````

output is 

````shell script
root@sylvain-hp:/home/sylvain# kubectl get po | grep mydeployment
mydeployment-7d5d555755-jwmzx                       1/1     Running            0          14m
root@sylvain-hp:/home/sylvain# kubectl exec -it  $(kubectl get po | grep mydeployment | awk '{print $1}') -- env | grep admin
USERNAME=admin
PASSWORD=admin123
````

Note adding annotation does not trigger pod restart.

I will now update the secret

````shell script
echo 'apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: admin123Stakater' > mysecret.yaml

kubectl apply -f mysecret.yaml

kubectl get po | grep mydeployment
kubectl exec -it  $(kubectl get po | grep mydeployment | awk '{print $1}') -- env | grep admin
````

Here we can see that the pod has been restarted! and thus environment var were updated.

````shell script
root@sylvain-hp:/home/sylvain# kubectl get po | grep mydeployment
mydeployment-7d5d555755-jwmzx                       0/1     Terminating        0          16m
mydeployment-7dddbb7fcc-98jv9                       1/1     Running            0          9s
root@sylvain-hp:/home/sylvain# kubectl exec -it  $(kubectl get po | grep mydeployment | awk '{print $1}') -- env | grep admin
PASSWORD=admin123Stakater
USERNAME=admin
````

There are third party solutions such as [Reloader](https://github.com/stakater/Reloader) for triggering [Pod] restarts when secrets change. [thus container restart by the Kubelet]

## Conclusion:  

If a container already consumed a secret in an environment variable, a secret update will not be seen by the container unless it [container] is restarted. [by the Kubelet]

See [Secrets consumed as environment variable and secret update](#secrets-consumed-as-environment-variable-and-secret-update).

There are third party solutions such as [Reloader](https://github.com/stakater/Reloader) for triggering [Pod] restarts when secrets change. [thus container restart by the Kubelet]

See [Third party solutions for triggering restarts when ConfigMaps and Secrets change](#third-party-solutions-for-triggering-restarts-when-configmaps-and-secrets-change)

See https://github.com/kubernetes/website/pull/25027 OK