# Access to multiple cluster

https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/#explore-the-homekube-directory

## Undertsand setup

Archlinux setup done [here](../Setup/ArchDevVM/archlinux-dev-vm-with-minikube.md).

````
➤ k config view                                                                                                                               vagrant@archlinuxapiVersion: v1
clusters:
- cluster:
    certificate-authority: /root/.minikube/ca.crt
    server: https://10.0.2.15:8443
  name: minikube
contexts:
- context:
    cluster: minikube
    user: minikube
  name: minikube
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
    client-certificate: /root/.minikube/client.crt
    client-key: /root/.minikube/client.key
[12:20] ~
➤ kubectl config view                                                                                                                         vagrant@archlinuxapiVersion: v1
clusters:
- cluster:
    server: https://openshift.remote.paas.scoulomb.net:8443
  name: openshift-remote-paas-scoulomb-net:8443
contexts:
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: apideploy-admin
    user: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  name: apideploy-admin/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: namespace-name-1
    user: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  name: namespace-name-1/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: namespace-name-2
    user: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  name: namespace-name-2/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: namespace-name-2
    user: system:serviceaccount:namespace-name-2:test-user/openshift-remote-paas-scoulomb-net:8443
  name: namespace-name-2/openshift-remote-paas-scoulomb-net:8443/system:serviceaccount:namespace-name-2:test-user
current-context: namespace-name-2/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
kind: Config
preferences: {}
users:
- name: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  user:
    token: a-token-value
- name: system:serviceaccount:namespace-name-2:test-user/openshift-remote-paas-scoulomb-net:8443
  user:
    token: a-long-sa-token-value
[12:20] ~

➤ cat .kube/config                                                                                                                            vagrant@archlinuxapiVersion: v1
clusters:
- cluster:
    server: https://openshift.remote.paas.scoulomb.net:8443
  name: openshift-remote-paas-scoulomb-net:8443
contexts:
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: apideploy-admin
    user: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  name: apideploy-admin/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: namespace-name-1
    user: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  name: namespace-name-1/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: namespace-name-2
    user: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  name: namespace-name-2/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: namespace-name-2
    user: system:serviceaccount:namespace-name-2:test-user/openshift-remote-paas-scoulomb-net:8443
  name: namespace-name-2/openshift-remote-paas-scoulomb-net:8443/system:serviceaccount:namespace-name-2:test-user
current-context: namespace-name-2/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
kind: Config
preferences: {}
users:
- name: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  user:
    token: a-token-value
- name: system:serviceaccount:namespace-name-2:test-user/openshift-remote-paas-scoulomb-net:8443
  user:
    token: a-long-sa-token-value
[12:20] ~
➤ sudo -i                                                                                                                                     vagrant@archlinux
[root@archlinux ~]# cat .kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority: /root/.minikube/ca.crt
    server: https://10.0.2.15:8443
  name: minikube
contexts:
- context:
    cluster: minikube
    user: minikube
  name: minikube
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
    client-certificate: /root/.minikube/client.crt
    client-key: /root/.minikube/client.key
[root@archlinux ~]#

[12:22] ~
➤ whoami                                                                                                                                      vagrant@archlinuxvagrant
[12:22] ~
➤ sudo -i                                                                                                                                     vagrant@archlinux[root@archlinux ~]# whoami
root
````
I am using vagrant user.
We can see that k (sudo kubectl) return the config which was setup by minikube with root
While kubectl return the config which was setup by OpenShift using vagrant user.

Minikube uses root user as we are using None driver which needs to be sudo.

We could use root user directly (sudo su) btw as done here:
https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/1-bind-in-docker-and-kubernetes/2-understand-source-ip-in-k8s.md#setup
and define alias without sudo for kubectl.

We recognize token, ns etc

This file can be found in .kube directory (of respective user so use sudo su to the one of root user)

In my setup the root is not targeting production cluster !


## Modify it 

As an exercise I will try configure my kube config to work with root user (the one editied by minikube) to target openshift

Commands are
````
# Token of test-user-sa retrieved from openshift configuration (kubectl) that will be set into minikube one (k=sudo kubectl)
set TOKEN (kubectl config view -o jsonpath='{.users[1].user.token}')

k config set-cluster openshift-remote-paas-scoulomb --server=https://openshift.remote.paas.scoulomb.net:8443 
k config set-credentials test-user-sa --token=$TOKEN
k config set-context openshift --cluster=openshift-remote-paas-scoulomb --namespace=namespace-name-2 --user=test-user-sa
k config use-context openshift
````

Output :

````
➤ k get po                                                    vagrant@archlinux
No resources found in default namespace.
[12:46] ~
➤ k config set-cluster openshift-remote-paas-scoulomb --server=https://openshift.remote.paas.scoulomb.net:8443
Cluster "openshift-remote-paas-scoulomb" set.
[12:47] ~
➤ k config set-credentials test-user-sa --token=$TOKEN        vagrant@archlinux
User "test-user-sa" set.
[12:47] ~
➤ k config set-context openshift --cluster=openshift-remote-paas-scoulomb --namespace=namespace-name-2 --user=test-user-sa
Context "openshift" created.
[12:47] ~
➤ k config use-context openshift                              vagrant@archlinux
Switched to context "openshift".
````

Usage :

````

➤ sudo systemd-resolve --flush-caches                         vagrant@archlinux
[12:48] ~
➤ k get po                                                    vagrant@archlinux
NAME                     READY   STATUS    RESTARTS   AGE
apodname-api-8-cg849   1/1     Running   0          5d
apodname-api-8-hdd8q   1/1     Running   0          2d
[12:48] ~
➤ k config use-context minikube                               vagrant@archlinux
Switched to context "minikube".
[12:49] ~
➤ k get po                                                    vagrant@archlinux
No resources found in default namespace.
````
We now can access opensift from root user config !


We can display new config

````
➤ k config view                                               vagrant@archlinuxapiVersion: v1
clusters:
- cluster:
    certificate-authority: /root/.minikube/ca.crt
    server: https://10.0.2.15:8443
  name: minikube
- cluster:
    server: https://openshift.remote.paas.scoulomb.net:8443
  name: openshift-remote-paas-scoulomb
contexts:
- context:
    cluster: minikube
    user: minikube
  name: minikube
- context:
    cluster: openshift-remote-paas-scoulomb
    namespace: namespace-name-2
    user: test-user-sa
  name: openshift
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
    client-certificate: /root/.minikube/client.crt
    client-key: /root/.minikube/client.key
- name: test-user-sa
  user:
    token: a-long-sa-token-value
[12:51] ~
````


Here I used .kube/config
https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/#explore-the-homekube-directory

## Environment var and config merge

And 
➤ echo $KUBE_CONFIG                                           vagrant@archlinux

Is empty 

If I follow guide here:
I can create a kube config in a given file

https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/#define-clusters-users-and-contexts
When running command to update specifically this file I should do:
--kubeconfig=config-demo 

and to see it 

kubectl config view --kubeconfig=config-demo

When doing `kubectl config view` it shows the config file in .kube directory 

Except if env var is set :

````
➤ export KUBECONFIG=/home/vagrant/config-exo/config-demo                                                                                      vagrant@archlinux[13:32] ~
➤ kubectl config view                                                                                                                         vagrant@archlinuxapiVersion: v1
clusters:
- cluster:
    certificate-authority: fake-ca-file
    server: https://1.2.3.4
  name: development
- cluster:
    server: ""
  name: scratch
contexts:
- context:
    cluster: ""
````


And we can merge 

````
export KUBECONFIG=/home/vagrant/config-exo/config-demo:/home/vagrant/.kube/config  
````

Output is 

````

➤ kubectl config view                                                                                                                         vagrant@archlinuxapiVersion: v1
clusters:
- cluster:
    certificate-authority: fake-ca-file
    server: https://1.2.3.4
  name: development
- cluster:
    server: https://openshift.remote.paas.scoulomb.net:8443
  name: openshift-remote-paas-scoulomb-net:8443
- cluster:
    server: ""
  name: scratch
contexts:
- context:
    cluster: openshift-remote-paas-scoulomb-net:8443
    namespace: apideploy-admin
    user: ldap-or-user-account-name/openshift-remote-paas-scoulomb-net:8443
  name: apideploy-admin/openshift-remote-paas-scoulomb-net:8443/ldap-or-user-account-name
- context:
    cluster: ""
    user: ""
  name: dev-frontend
  
````

## Wrap up

So I reused full doc 

https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/#linux-1
Note here `:` is to separate config 1 from 2

My approach is to check my setup with config in .kube
The one from task is to 
Create 2 config 
And change env var to point to it 
With the mention we have `.kube` file here
https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/#explore-the-homekube-directory

The two approaches are ok and this task is fully understood 

## Exam 

From exam handbook either we do ssh to master node which has the good kube config
or access it with Kubectl (use `kubectl config use-context` to switch to the good context) or edit manually the file (.kube directory, no edit seems possible).

Cf exam :
You can use kubectl and the appropriate context to work on any cluster from the base node.
When connected to a cluster member via ssh, you will only be able to work on that particular
cluster via kubectl.

So can also do ssh vagrant@node


Also we had done this:

````
➤ k config set-context openshift --cluster=openshift-remote-paas-scoulomb --namespace=namespace-name-2 --user=test-user-sa
Context "openshift" created.
[12:47] ~
➤ k config use-context openshift                              vagrant@archlinux
Switched to context "openshift".
````

From cheathseet:
````shell script
k config set-context --current --namespace=ggckad-s2
````


So I guess doing this will modify current default ns 

And this can be seen here (it modifes the current context):

````
[13:44] ~
➤ k config view | grep -A 5 context                           vagrant@archlinuxcontexts:
- context:
    cluster: minikube
    user: minikube
  name: minikube
- context:
    cluster: openshift-remote-paas-scoulomb
    namespace: namespace-name-2
    user: test-user-sa
  name: openshift
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
[13:44] ~
➤ k config set-context --current --namespace=ggckad-s2        vagrant@archlinuxContext "minikube" modified.
[13:44] ~
➤ k config view | grep -A 5 context                           vagrant@archlinuxcontexts:
- context:
    cluster: minikube
    namespace: ggckad-s2
    user: minikube
  name: minikube
- context:
    cluster: openshift-remote-paas-scoulomb
    namespace: namespace-name-2
    user: test-user-sa
  name: openshift
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
[13:44] ~
➤ k config set-context --current --namespace=yolo             vagrant@archlinux
Context "minikube" modified.
[13:45] ~
➤ k config view | grep -A 5 context                           vagrant@archlinux
contexts:
- context:
    cluster: minikube
    namespace: yolo
    user: minikube
  name: minikube
- context:
    cluster: openshift-remote-paas-scoulomb
    namespace: namespace-name-2
    user: test-user-sa
  name: openshift
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
[13:45] ~
➤ k get po                                                    vagrant@archlinuxN
o resources found in yolo namespace.
[13:45] ~
➤                                                             vagrant@archlinux
````


Reset:
`k config set-context --current --namespace=default` (explicit?????osef)
 
 other specifed `-n` at each command
 
 If using oc client and doing `oc projects` we can realize namespace is modified in kube context.
 
 
 `openshift.remote.paas.scoulomb.net` could be a corporate openshift cluster.