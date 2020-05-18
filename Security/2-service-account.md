# Service account

From [doc](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account)
> When you (a human) access the cluster (for example, using kubectl), you are authenticated by the apiserver as a particular User Account (currently this is usually admin, unless your cluster administrator has customized your cluster). Processes in containers inside pods can also contact the apiserver. When they do, they are authenticated as a particular Service Account (for example, default).

## Clean up from previous run

k delete pod app app
k delete sa specific-service-account
k delete rolebinding specific-cluster-role-binding
k delete clusterrole specific-cluster-role

## Default service account inspection

Run [FINAL STEP] of [previous lab](./1-secret-creation-consumption.md) 

### Listing secret

When using default service account from previous step:

````
$ k get secret
NAME                  TYPE                                  DATA   AGE
database-secret       Opaque                                1      97m
default-token-vfgrk   kubernetes.io/service-account-token   3      72d
````

We can see we have the database secret but also a default token secret

````
$ k get secret default-token-vfgrk -o yaml                     
apiVersion: v1                                                 
data:                                                          
  ca.crt: LS0tLS1CRUdJT[...]
````

### Looking at pod details 


````
vagrant@k8sMaster:~/tutu
$ k describe pod app | grep -C 5 secret
    Ready:          True
    Restart Count:  1
    Environment:    <none>
    Mounts:
      /mariadb-password from mariadb (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-vfgrk (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  mariadb:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  database-secret
    Optional:    false
  default-token-vfgrk:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-vfgrk
    Optional:    false
````
We can see we mount mariadb password secret, but also a volume with token and ca specific to default sa.
We can see its content:

````
vagrant@k8sMaster:~/tutu
$ k exec -it app -- /bin/sh
/ $ cat /var/run/secrets/kubernetes.io/serviceaccount/
..2020_04_11_09_28_45.938303516/  namespace
..data/                           token
ca.crt
/ $ cat /var/run/secrets/kubernetes.io/serviceaccount/token
eyJhbGciOiJSUzI1NiIsImtpZCI6IktLb2R6clJHaENCa3RuZGt2VllqZGROY2R5Q2R0
````

https://stackoverflow.com/questions/30690186/how-do-i-access-the-kubernetes-api-from-within-a-pod-container

### Target K8s api from a POD with that default token

````
k exec -it app -- /bin/sh
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1 -O -
````

Output is:
````
/ $ wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1 -O -
Connecting to 10.96.0.1 (10.96.0.1:443)
writing to stdout
{
  "kind": "APIResourceList",
  "groupVersion": "v1",
  "resources": [
[...]

````

We will use this  Script to LIST pod and secret. 

````
k exec -it app -- /bin/sh 
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/pods -O -
wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/secrets -O -
exit
````

Output is that we are forbidden to this ressource!

````
$ k exec -it app -- /bin/sh
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/pods -O -
w/ $ KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
/ $ wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" htt
ps://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/pods -O -
Connecting to 10.96.0.1 (10.96.0.1:443)
wget: server returned error: HTTP/1.1 403 Forbidden
/ $ wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/secrets -O -
Connecting to 10.96.0.1 (10.96.0.1:443)
wget: server returned error: HTTP/1.1 403 Forbidden
````


## Use a specific service account

### Create a service account and use it in the pod

````
echo '
apiVersion: v1
kind: ServiceAccount
metadata: 
  name: specific-service-account
' > specific-service-account.yaml

k create -f specific-service-account.yaml

echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  serviceAccountName: specific-service-account
  securityContext:
    runAsUser: 1000
  containers:
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
    securityContext:
      runAsUser: 2000
      capabilities : 
        add: ["NET_ADMIN", "SYS_TIME"]
    volumeMounts:
    - name: mariadb
      mountPath: /mariadb-password
  volumes:
  - name: mariadb
    secret:
      secretName: database-secret
' > app.yaml

k delete -f app.yaml
k create -f app.yaml

````
### Tests

#### Listing 

Creating a new service account created a new secret:

````
$ k get secret
NAME                                   TYPE                                  DATA   AGE
database-secret                        Opaque                                1      3h8m
default-token-vfgrk                    kubernetes.io/service-account-token   3      72d
specific-service-account-token-rfppd   kubernetes.io/service-account-token   3      46s
````

#### Looking at pod details 


````
vagrant@k8sMaster:~/tutu
$ k describe pod app | grep -C 5 secret
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /mariadb-password from mariadb (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from specific-service-account-token-dq4wv (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             True
  ContainersReady   True
  PodScheduled      True
Volumes:
  mariadb:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  database-secret
    Optional:    false
  specific-service-account-token-dq4wv:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  specific-service-account-token-dq4wv
    Optional:    false
````
We can now see, that now rather than mounting default-token secret, we use specific=service-account secret!


#### Target K8s api from a POD with that default token

Output is FORBIDDEN

````
vagrant@k8sMaster:~/tutu
$ k exec -it app -- /bin/sh
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/pods -O -
wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/secrets -O -
exit/ $ KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
/ $ wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" htt
ps://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/pods -O -
Connecting to 10.96.0.1 (10.96.0.1:443)
wget: server returned error: HTTP/1.1 403 Forbidden
/ $ wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/secrets -O -
Connecting to 10.96.0.1 (10.96.0.1:443)
wget: server returned error: HTTP/1.1 403 Forbidden
/ $ exit
command terminated with exit code 1
````

However not I can still see my MOUNTED secret:

````
$ k exec -it app -- /bin/sh
/ $ cat /mariadb-password/password
p@ssw3od
/ $ cat /var/run/secrets/kubernetes.io/serviceaccount/token
eyJhbGciOiJSUzI1NiIsImtpZCI6IktLb2R6clJHaENCa3RuZGt2VllqZGROY2R5Q2R0L
````

## Give rigth to this specific service account 

### Create cluster role

Take admin one as inpiration

````
k get clusterroles cluster-admin -o yaml > specific-cluster-role.yaml
```` 

After edition we have

````
echo '{
  "apiVersion": "rbac.authorization.k8s.io/v1",
  "kind": "ClusterRole",
  "metadata": {
    "name": "specific-cluster-role"
  },
  "rules": [
    {
      "apiGroups": [
        "*"
      ],
      "resources": [
        "secrets",
        "pods"
      ],
      "verbs": [
        "get",
        "list"
      ]
    }
  ]
}' > specific-cluster-role.json

k create -f specific-cluster-role.json
````
So that we can see it

````
$ k get clusterrole specific-cluster-role -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
````

### Then create role binding between specific service account and specific cluster role

Start from this file
````
$ k get rolebinding kube-proxy -n kube-system -o yaml > specific-role-binding.yaml
````

After edit (not Role != ClusterRole)

````
echo '
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: specific-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: specific-cluster-role
subjects:
- kind: ServiceAccount
  name: specific-service-account' > specific-role-binding.yaml
k create -f specific-role-binding.yaml

````

Then

````
$ k get rolebindings
NAME                            AGE
specific-cluster-role-binding   69s
````

No need to restart the pod

### Tests


#### Target K8s api from a POD with that default token


Output is

````
vagrant@k8sMaster:~/tutu
$ k exec -it app -- /bin/sh
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/pods -O -
w/ $ KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
/ $ wget --no-check-certificate --header "Authorization: Bearer $KUBE_TOKEN" htt
ps://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/pods -O -
Connecting to 10.96.0.1 (10.96.0.1:443)
writing to stdout
{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/namespaces/default/pods",
    "resourceVersion": "640345"
  }, [...]
N4b1lxdVlrbmQ4S2sxSXB1eVFxUXBnTTIxLVducTgtY3Fuc2VZYzJ2SnhVWDRtaEpKZDBkR0xyeGxSTG1QQ2dmLVpDRUQ1QzZBa09vMVZWTFE="
      },
      "type": "kubernetes.io/service-account-token"
    }
  ]
-                    100% |****************************************************|  7202  0:00:00 ETA written to stdout
/ $ exit  
````

it is working

## Disable auto mount

In pod spec (or in sa), we can add the field: `automountServiceAccountToken: false`.
In that case the service account token will not be mounted.
                                                                  
````shell script
➤ k describe pods app | grep -A 5 Mounts                                      vagrant@archlinux
    Mounts:
      /mariadb-password from mariadb (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from specific-service-account-token-b5trt (ro)
Conditions:
  Type              Status
  Initialized       True
[10:13] ~
➤ vim app.yaml                                                                vagrant@archlinux
[10:15] ~
➤ k delete -f app.yaml                                                        vagrant@archlinux
pod "app" deleted
[10:15] ~
➤ k create -f app.yaml                                                        vagrant@archlinux
pod/app created
[10:16] ~
➤ k describe pods app | grep -A 5 Mounts                                      vagrant@archlinux
    Mounts:
      /mariadb-password from mariadb (rw)
Conditions:
  Type              Status
  Initialized       True
  Ready             False
[10:16] ~
➤                                                                             vagrant@archlinux
````

This is documented here:
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#use-the-default-service-account-to-access-the-api-server
- https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#use-multiple-service-accounts    

Note we can create a secret from a service account:
https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#use-multiple-service-accounts

     
                                                                  
## Link secret to service account

### Change secret to use something different than sa

````
k delete sa --all
k delete pod --all
k delete secret --all

echo '
apiVersion: v1
kind: Secret
metadata:
   name: database-secret
data:
   password: cEBzc3czb2QK' > database-secret.yaml

k create -f database-secret.yaml

echo '
apiVersion: v1
kind: ServiceAccount
metadata: 
  name: specific-service-account
' > specific-service-account.yaml

k create -f specific-service-account.yaml

secrets:
- name: specific-service-account-token-7s2s2 => database-secret
➤ k edit serviceaccount/specific-service-account                              vagrant@archlinux
serviceaccount/specific-service-account edited

echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  serviceAccountName: specific-service-account
  securityContext:
    runAsUser: 1000
  containers:
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
' > app.yaml

k create -f app.yaml

````

output show it has been ignored, it recreates the secret lnked to service account
And mdified name of database secret which is ignored as not existing.

````shell script
➤ k describe pods app | grep -A 5 Mounts                                      vagrant@archlinux
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from specific-service-account-token-b4g5b (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             False
[10:28] ~
➤ k exec -it app -- /bin/sh                                                   vagrant@archlinux/ $ ls /var/run/secrets/kubernetes.io/serviceaccount
ca.crt     namespace  token
/ $ cat /var/run/secrets/kubernetes.io/serviceaccount/token
eyJhbGciOiJSUzI1NiIsImtpZCI6Ii0yZG5pR1lUQlBLQXRxTmFzOEhJNXJpaEl5ZTNwdmdaMWU2NktET0tETTQifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InNwZWNpZmljLXNlcnZpY2UtYWNjb3VudC10b2tlbi1iNGc1YiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJzcGVjaWZpYy1zZXJ2aWNlLWFjY291bnQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJlMTllYmUwNi03MzY0LTQ0YmItYjg3Yy05NGRiYjBjMDYwOWUiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZGVmYXVsdDpzcGVjaWZpYy1zZXJ2aWNlLWFjY291bnQifQ.tCRsMYkK8UhE6bzvsdtKQbKK1Gu9tbDPhMmZ8Hgm7JN3EK7w9u9POasVP5XYzefJOYcBgKFjiJC5jSNPnjoX8ZfkaOIxRgzt0qBwhhjWMqvb18RJVH-LMJwTF13eJ_aSb-ov3bAjpP3D7r1NRltl8E0fTlmH14OX3XiK6csfjQIVGMb9G3B7MXbxUTcq5Wuoz4DBxLk50FSsG8XGhZgxs7ChVY-XMk3NhOW9-3RLJJXbn3sV-X50PFgjQoBPlsH1K2oheYSCa0fEP1skk1fdqJj_0GWRawqq-hiJt72Ixig7wPo1E1sh5_IV6r-fQDyrfqYCMnqTFqZtY1AGHrjnsg/ $
/ $ exit
[10:29] ~
➤ k get sa                                                                    vagrant@archlinuxNAME                       SECRETS   AGE
default                    1         7m42s
specific-service-account   2         6m42s
[10:30] ~
➤ k get sa specific-service-account -o yaml                                   vagrant@archlinuxapiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2020-05-18T10:23:22Z"
  name: specific-service-account
  namespace: default
  resourceVersion: "67805"
  selfLink: /api/v1/namespaces/default/serviceaccounts/specific-service-account
  uid: e19ebe06-7364-44bb-b87c-94dbb0c0609e
secrets:
- name: database-secreunt-token-7s2s2
- name: specific-service-account-token-b4g5b
[10:30] ~
➤ k get secrets                                                               vagrant@archlinuxNAME                                   TYPE                                  DATA   AGE
database-secret                        Opaque                                1      7m35s
default-token-l5d2z                    kubernetes.io/service-account-token   3      8m8s
specific-service-account-token-7s2s2   kubernetes.io/service-account-token   3      7m18s
specific-service-account-token-b4g5b   kubernetes.io/service-account-token   3      4m22s
````

This secret is dedicated to service account.
We should use pod pre-set:
https://kubernetes.io/docs/concepts/configuration/secret/#automatic-mounting-of-manually-created-secrets

### Associate pull secret to a service account

https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account

````buildoutcfg
➤ k get sa                                                                    vagrant@archlinux
NAME                       SECRETS   AGE
default                    1         57m
specific-service-account   2         56m

➤ kubectl create secret docker-registry myregistrykey2 --docker-server=DOCKER_REGISTRY_SERVER --docker-username=DOCKER_USER --docker-password=DOCKER_PASSWORD --docker-email=DOCKER_EMAIL
secret/myregistrykey2 created

➤ k get sa default -o yaml                                                    vagrant@archlinux
apiVersion: v1
imagePullSecrets:
- name: myregistrykey2e
kind: ServiceAccount
[...]
secrets:
- name: default-token-l5d2z

➤ k get pod app -o yaml                                                       vagrant@archlinuxapiVersion: v1
kind: Pod
[...]
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: specific-service-account-token-b4g5b
      readOnly: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  nodeName: archlinux
  priority: 0
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext:
    runAsUser: 1000
  serviceAccount: specific-service-account
  serviceAccountName: specific-service-account
  terminationGracePeriodSeconds: 30
[...]
  volumes:
  - name: specific-service-account-token-b4g5b
    secret:
      defaultMode: 420
      secretName: specific-service-account-token-b4g5b


# In app.yaml we remove `spec.serviceAccountName: specific-service-account` and recreate the pod
➤ cat app.yaml                                                                vagrant@archlinux
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"

➤ k create -f app.yaml                                                        vagrant@archlinu
xpod/app created
[11:14] ~
➤ k get pod app -o yaml                                                       vagrant@archlinux
apiVersion: v1
kind: Pod
[...]
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-l5d2z
      readOnly: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  imagePullSecrets:
  - name: myregistrykey2e
 [...]
  volumes:
  - name: default-token-l5d2z
    secret:
      defaultMode: 420
      secretName: default-token-l5d2z
````

We can that in pod `imagePullSecret` is added (with volune mount too) because image pull secret is related to default sa.
==> https://github.com/kubernetes/website/pull/21043


## SA vol projection

We saw auto mount of sa.
We can also decide where to mount it:
https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection

I skipped: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-issuer-discovery
 

We will now [see network policy](./3-1-network-policy-NoPolicy.md).
