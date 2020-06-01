# Autocompletion

<!--
I will test this with hp laptop with kubectl 1.18
Unlike alais in vm where k=sudo kubectl; I will here do sudo -i.
We need sudo asusing minikube with none driver.
-->

Doc: https://kubernetes.io/docs/reference/kubectl/cheatsheet/#bash

````
sylvain@sylvain-hp:~$ sudo -i
[sudo] password for sylvain: 
root@sylvain-hp:~# source <(kubectl completion bash) 
root@sylvain-hp:~# echo "source <(kubectl completion bash)" >> ~/.bashrc
root@sylvain-hp:~# alias k=kubectl
root@sylvain-hp:~# complete -F __start_kubectl k
root@sylvain-hp:~# k run --image=alpine --re
--record            --requests=         --restart
--recursive         --request-timeout   --restart=
--requests          --request-timeout=  
root@sylvain-hp:~# k run --image=alpine --re
--record            --requests=         --restart
--recursive         --request-timeout   --restart=
--requests          --request-timeout=  
root@sylvain-hp:~# k run test --image=alpine --restart=Never --dry-run=client -o yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: test
  name: test
spec:
  containers:
  - image: alpine
    name: test
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}
root@sylvain-hp:~# k run test --image=alpine --restart=Never
pod/test created
root@sylvain-hp:~# k get pod
poddisruptionbudgets.policy  podsecuritypolicies.policy
pods                         podtemplates
root@sylvain-hp:~# k get pods test
NAME   READY   STATUS      RESTARTS   AGE
test   0/1     Completed   0          10s
root@sylvain-hp:~# k run test2 --image=alpine --restart=Never
pod/test2 created
root@sylvain-hp:~# k get pods test
test                   test2                  test-7b46796d56-754pt
````
