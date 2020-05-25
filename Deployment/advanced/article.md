luska cettepartie seulement,truc avant clair
voir controller

sudo minikube start --vm-driver=none

# https://kubernetes.io/fr/docs/reference/kubectl/cheatsheet/
source <(kubectl completion bash) # active l'auto-complétion pour bash dans le shell courant, le paquet bash-completion devant être installé au préalable
echo "source <(kubectl completion bash)" >> ~/.bashrc # ajoute l'auto-complétion de manière permanente à votre shell bash

alias k='sudo kubectl' # Add sudo
complete -F __start_kubectl k

k delete deplyoyment --all
k delete svc --all

sleep 3

# I will show deployment of the  differenet vrsion inin home/sample
I could have used  a rediness like this https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-a-liveness-command

and then adaptbelow

k create deployment test --image=nginx:1.15 --dry-run=client -o yaml
k create deployment test --image=nginx:1.15 # use create deployment synthax without save-config option leads to a warning when doing k apply -f to update the deployment; as I will change the image pull policy I will export a YAML and apply it.

create deployment file and follow templare below

k rollout history deployment test
k get po

sleep 3

k set image deployment/test  nginx=nginx:1.16 --record

k rollout history deployment test
k get po


k scale deployment/test --replicas=3
sleep 3
k get po

k rollout history deployment test # no new rollout is triggered

cat << EOF | k apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: test
  name: test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: test
    spec:
      containers:
      - image: nginx:1.16
        name: nginx
        resources: {}
status: {}
EOF

 
k rollout history deployment test
k get po # no rollout but scaled

k scale deployment/test --replicas=3
k get po

# Adding a readiness
# https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#define-a-liveness-command

cat << EOF | k apply -f - --record
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: test
  name: test
spec:
  # replicas: 1 # to not scale
  selector:
    matchLabels:
      app: test
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: test
    spec:
      containers:
      - image: nginx:1.16
        name: nginx
        args:
          - /bin/sh
          - -c
          - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
        readinessProbe:
          exec:
            command:
              - cat
              - /tmp/healthy
          initialDelaySeconds: 5
          periodSeconds: 5 
        resources: {}
status: {}
EOF

 
k rollout history deployment test
k get po


k expose deployment test --port 8089 --record
# not unlikepod no port created


IP=$(k get svc test -o jsonpath='{.spec.clusterIP}')

make examplebased on this
https://github.com/scoulomb/zalando_connexion_sample/tree/master/.flask_flavour

