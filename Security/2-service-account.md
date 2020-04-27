# Service account

## Clean up from previous run

k delete pod app app
k delete sa specific-service-account
k delete rolebinding specific-cluster-role-binding
k delete clusterrole specific-cluster-role

## Default service account inspection

Run [FINAL STEP] of [previous lab](./secret-creation-consumption.txt) 

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

We will now [see network policy](./3-1-network-policy-NoPolicy.md).