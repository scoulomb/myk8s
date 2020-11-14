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
    - and subpart my pr?
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

### v3 (pr)
title:  Environment variables are not updated after a secret update

If a container already consumed a secret in an environment variable, secret update will not cascade update to the container.
But if the Kubelet restarts the container, secret update will be available.
=> if pod deleted and restarted it is obvious we have the update  
````

<!-- concluded jsut pr k8s website to add 
 when doing pr in my k8s could have one update branch we rebase everytime OK-->
PR => https://github.com/kubernetes/website/pull/25027