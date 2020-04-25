# Vagrant file

Setup a VM with a real Kubernetes environment (not using minikube)

## Prereq

- Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- Install [Vagrant](https://www.vagrantup.com/downloads.html) 
- Disable hypervisor. More info [here in SO](https://stackoverflow.com/questions/50053255/virtualbox-raw-mode-is-unavailable-courtesy-of-hyper-v-windows-10), remove it for docker to work
- Use ConEmu and configure it to open a git bash to this folder or cd to this folder using git bash

Note: This will make docker for windows stop working.

## Run vagrant file the first time

The first time setup guest addition
````buildoutcfg
vagrant plugin install vagrant-vbguest # Install guest addition
````

Then 

````buildoutcfg
cd /c/git_pub/myk8s/Setup/ClusterSetup
vagrant up
vagrant ssh k8sMaster # k8sMaster is optional given we have a single machine here
````

The command takes a while to run the first time

We could export a VM but it is [dirty](https://stackoverflow.com/questions/20679054/how-to-export-a-vagrant-virtual-machine-to-transfer-it
).

See [Known issues](#known-issues) in case of problem.

## Daily usage

````buildoutcfg
vagrant up
vagrant ssh
````

You can use 

````buildoutcfg
vagrant up --provision 
````

To run again shell scripts after the first start-up.

To just restart API server after VM shut down use `restart.sh` script. 
 
````buildoutcfg
bash /vagrant/restart.sh
````

To avoid this we can use

````buildoutcfg
vagrant suspend
vagrant resume
````

## Reset

````buildoutcfg
vagrant destroy ; vagrant up
````

## Known issues

### Docker setup failing

We could have this error when doing the [setup](#Run vagrant file the first time)
This seems recurrent at each fresh install.

````buildoutcfg
k8sMaster: E: Failed to fetch http://archive.ubuntu.com/ubuntu/pool/universe/c/containerd/containerd_1.3.3-0ubuntu1~18.04.2_amd64.deb  503  Service Unavailable [IP: 91.189.88.142 80]
````

I did `vagrant ssh`, setup by hand `docker` and re-run setup scripts.

````buildoutcfg
sudo apt-get install -y docker.io;bash /vagrant/k8sMaster.sh | tee ~/master.out
bash /vagrant/removeTaints.sh
````

And check it works

````buildoutcfg
k get pods --all-namespaces
kubectl create deployment nginx --image=nginx
k get pods
````
This is ok.

For example we could have another issue:

````buildoutcfg
vagrant@k8sMaster:~$ k get pods --all-namespaces
NAMESPACE     NAME                                       READY   STATUS                  RESTARTS   AGE
kube-system   calico-kube-controllers-6b9d4c8765-mbw2n   0/1     Pending                 0          25s
kube-system   calico-node-jlfvj                          0/1     Init:ImagePullBackOff   0          25s
kube-system   coredns-5644d7b6d9-tm462                   0/1     Pending                 0          6m37s
kube-system   coredns-5644d7b6d9-wblf2                   0/1     Pending                 0          6m37s
kube-system   etcd-k8smaster                             1/1     Running                 0          6m5s
kube-system   kube-apiserver-k8smaster                   1/1     Running                 0          5m59s
kube-system   kube-controller-manager-k8smaster          1/1     Running                 0          6m15s
kube-system   kube-proxy-7rmb9                           1/1     Running                 0          6m37s
kube-system   kube-scheduler-k8smaster                   1/1     Running                 0          5m58s
````

There is a pull image error on CalicoNode

as such the node is not ready

````buildoutcfg
vagrant@k8sMaster:~$ k describe node |grep NetworkReady
  Ready            False   Fri, 24 Apr 2020 22:24:03 +0000   Fri, 24 Apr 2020 21:50:42 +0000   KubeletNotReady              runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized
vagrant@k8sMaster:~$ k get nodes
NAME        STATUS     ROLES    AGE   VERSION
k8smaster   NotReady   master   34m   v1.16.1
````

If we create a pod `kubectl create deployment nginx --image=nginx`.
It will not be scheduled, because the node has the taint not ready
````buildoutcfg
vagrant@k8sMaster:~$ k describe po | grep FailedScheduling
  Warning  FailedScheduling  <unknown>  default-scheduler  0/1 nodes are available: 1 node(s) had taints that the pod didn't tolerate.
  Warning  FailedScheduling  <unknown>  default-scheduler  0/1 nodes are available: 1 node(s) had taints that the pod didn't tolerate.
````

It was due to an error on `insecureCertificate` script (CR/LF).
See [fix line separator issue](../FixLineSpeparatorIssue.md).
So I run the script again, delete the calico pod and it worked

````buildoutcfg
vagrant@k8sMaster:~$ k get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-86c57db685-vl8pb   1/1     Running   0          89m
````

## Deploy local registry

````buildoutcfg
cd /vagrant/LocalRegistrySetup
sudo ./deploy-local-registry.sh
````

## Gitconfig

See https://github.com/scoulomb/env-config/blob/master/.gitconfig