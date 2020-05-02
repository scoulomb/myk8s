# DEV setup

## Deploy Guest Archlinux VM with Vagrant 

1. Dev VM : https://github.com/scoulomb/dev_vm?organization=scoulomb&organization=scoulomb
    - Clone dev_vm into dev directory in $HOME windows
    - change hashicop insecure curl
    - change git config 
    - In vagrantfile: change vagrant $USER in sync folder, adapt CPU and RAM, eventually add port fw (1313 for kubedoc)
    - `$USER` in fish function
2. restart machine and ensure connected to internet
3. `vagrant up; vagrant ssh`

You could have some package download error:

````
          ID: common_packages
    Function: pkg.installed
        Name: git
      Result: False
     Comment: Problem encountered installing package(s). Additional info follows:
	[...]
                error: failed retrieving file 'git-2.25.1-1-x86_64.pkg.tar.zst' from mirror.reisenbauer.ee : The requested URL returned error: 404
                    error: failed retrieving file 'git-2.25.1-1-x86_64.pkg.tar.zst' from mirror.reisenbauer.ee : The requested URL returned error: 404

-------------
Succeeded: 23 (changed=22)
Failed:     1
-------------
Total states run:     24
Total run time: 1437.082 s
````


## Setup Kubernetes on this dev machine  

### Setup yaourt package manager

Aura is already there but all tuto I found for minikube are with yaourt!

Follow this tuto: https://cloudcone.com/docs/article/install-packages-in-arch-linux-from-aur/ (Section > "install yaout using AUR")

````
sudo pacman -S --needed base-devel git wget yajl
sudo git clone https://aur.archlinux.org/package-query.git # Add sudo
cd package-query/ # May need to perform chmod
makepkg -si
git clone https://aur.archlinux.org/yaourt.git
cd yaourt/
makepkg -si
````
### Install minikube

````
yaourt -S minikube
sudo minikube start --vm-driver=none
````

This failed thus I Followed this procedure: https://www.howtoforge.com/learning-kubernetes-locally-via-minikube-on-linux-manjaro-archlinux/

````
sudo pacman -Sy libvirt qemu ebtables dnsmasq

sudo usermod -a -G libvirt $(whoami)
newgrp libvirt

sudo systemctl start libvirtd.service
sudo systemctl enable libvirtd.service
 
sudo systemctl start virtlogd.service
sudo systemctl enable virtlogd.service

sudo pacman -Sy docker-machine
yaourt -Sy docker-machine-driver-kvm2

yaourt -Sy minikube-bin kubectl-bin
````

If error re-run the command, conflcit with existing ERASE (kubectl, docker already there as deployed with Salt. Added git)


### Trying minkube (and the different driver)

<details><summary>show all drivers</summary>
<p>

#### kvm driver [Not working]
when launching minikube driver error with kvm because of nested virtulization
https://github.com/minishift/minishift/issues/3075
Thus previous install could have been simplfied 

#### Docker  driver [Certificate issue]

so use docker driver

and magic happens 
https://minikube.sigs.k8s.io/docs/drivers/docker/
````
➤ minikube start --driver=docker                                                                                                                                              vagrant@archlinux😄  minikube v1.9.2 on Arch  (vbox/amd64)
✨  Using the docker driver based on user configuration
👍  Starting control plane node m01 in cluster minikube
🚜  Pulling base image ...
🔥  Creating Kubernetes in docker container with (CPUs=2) (4 available), Memory=2200MB (3841MB available) ...
🐳  Preparing Kubernetes v1.18.0 on Docker 19.03.2 ...
    ▪ kubeadm.pod-network-cidr=10.244.0.0/16
🌟  Enabling addons: default-storageclass, storage-provisioner
🏄  Done! kubectl is now configured to use "minikube"
[22:41] ~
````

But when launching a pod, I had a pull isse

````
  Normal   Pulling      7s (x2 over 20s)  kubelet, minikube  Pulling image "nginx"
  Warning  Failed       6s (x2 over 20s)  kubelet, minikube  Failed to pull image "nginx": rpc error: code = Unknown desc = Error response from daemon: Get https://registry-1.docker.io/v2/: x509: certificate signed by unknown authority
  Warning  Failed       6s (x2 over 20s)  kubelet, minikube  Error: ErrImagePull
[23:03] ~
````

This is due to certificate issue but they are already deployed with Salt...
In doubt I re-used this proc https://github.com/scoulomb/myk8s/blob/master/Setup/MinikubeSetup/insecureCertificate.sh

Except need had to `mkdir /usr/local/share/ca-certificates/` and cmd is ` sudo update-ca-trust` with Archlinux.
Then I restart minikube but issue still there.

It is because insecure registry is correct in VM docker setup but not in the driver (kVM running in archlinux VM) 
Here is a proof


````
➤ docker pull nginx                                                                                                                                                           vagrant@archlinuxUsing default tag: latest
latest: Pulling from library/nginx
54fec2fa59d0: Pull complete
4ede6f09aefe: Pull complete
f9dc69acb465: Pull complete
Digest: sha256:86ae264c3f4acb99b2dee4d0098c40cb8c46dcf9e1148f05d3a51c4df6758c12
Status: Downloaded newer image for nginx:latest
docker.io/library/nginx:latest
````
We can try to  use `--insecure-registry` flag but it seems there is some issue with it 

````
➤ sudo systemctl restart docker                                                                                                                                               vagrant@archlinux[00:46] ~
➤ minikube delete                                                                                                                                                             vagrant@archlinux🔥  Removing /home/vagrant/.minikube/machines/minikube ...
💀  Removed all traces of the "minikube" cluster.
[00:46] ~
➤ rm -rf  ~/.minikube/machines/minikube                                                                                                                                       vagrant@archlinux[00:46] ~
[00:46] ~
➤ minikube start --driver=docker --insecure-registry "registry-1.docker.io"  # or with :443                                                                                                   vagrant@archlinux😄  minikube v1.9.2 on Arch  (vbox/amd64)
✨  Using the docker driver based on user configuration
👍  Starting control plane node m01 in cluster minikube
🚜  Pulling base image ...
🔥  Creating Kubernetes in docker container with (CPUs=2) (4 available), Memory=2200MB (3841MB available) ...
🐳  Preparing Kubernetes v1.18.0 on Docker 19.03.2 ...
    ▪ kubeadm.pod-network-cidr=10.244.0.0/16
🌟  Enabling addons: default-storageclass, storage-provisioner
🏄  Done! kubectl is now configured to use "minikube"
[00:47] ~
➤ kubectl run nginxwkkfffk --image=nginx                                                                                                                                      vagrant@archlinuxError from server (Forbidden): pods "nginxwkkfffk" is forbidden: error looking up service account default/default: serviceaccount "default" not found
                                                                                                                                                 vagrant@archlinuxNAME           READY   STATUS         RESTARTS   AGE
nginxwkkfffk   0/1     ErrImagePull   0          5s
[00:47] ~
➤
````
Still error

Issue with this flag:
- https://github.com/kubernetes/minikube/issues/4547
- https://github.com/kubernetes/minikube/issues/604

I could pull policy in local but not convnient 

strategy change

</p>
</details>

####  Use bare metal - None driver

we need to be sudo (unlike Docker where we can not)

##### Install conntrack

````
💣  Sorry, Kubernetes v1.18.0 requires conntrack to be installed in root's path
[00:49] ~
➤ sudo minikube start --driver=none                                                                                                                                           vagrant@archlinux😄  minikube v1.9.2 on Arch  (vbox/amd64)
✨  Using the none driver based on user configuration
💣  Sorry, Kubernetes v1.18.0 requires conntrack to be installed in root's path
````

Here is the packageL https://www.archlinux.org/packages/extra/x86_64/conntrack-tools/
 

```` 
➤ yaourt -Sy conntrack-tools                                                                                                                                                  vagrant@archlinux:: Synchronizing package databases...

➤ sudo -s                                                                                                                                                                     vagrant@archlinuxWelcome to fish, the friendly interactive shell
Type `help` for instructions on how to use fish
root@archlinux /h/vagrant# minikube start --vm-driver=none
😄  minikube v1.9.2 on Arch  (vbox/amd64)
[...]
❗  The 'none' driver is designed for experts who need to integrate with an existing VM
💡  Most users should use the newer 'docker' driver instead, which does not require root!
📘  For more information, see: https://minikube.sigs.k8s.io/docs/reference/drivers/none/

❗  kubectl and minikube configuration will be stored in /root
❗  To use kubectl or minikube commands as your own user, you may need to relocate them. For example, to overwrite your own settings, run:

    ▪ sudo mv /root/.kube /root/.minikube $HOME
    ▪ sudo chown -R $USER $HOME/.kube $HOME/.minikube

💡  This can also be done automatically by setting the env var CHANGE_MINIKUBE_NONE_USER=true
🏄  Done! kubectl is now configured to use "minikube"

root@archlinux /h/vagrant# kubectl run nginx --image=nginx
pod/nginx created
root@archlinux /h/vagrant# kubectl get pods
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          7s
root@archlinux /h/vagrant#



````

It is working :)

Exit root and define some aliases:

````
exit #(root)
alias k=sudo kubectl
````

And try with fish 

````
➤ k get pods                                                                                                  vagrant@archlinux
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   1          9h
````

And bash 

````
➤ bash -c 'sudo kubectl get pods'     
vagrant@archlinux
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   1          9h
````

Doing kubectl auto completions id not working with `bash -c`.


### Define permanenent fish helper (with sudo access to kubecltl and autocompletion)

Objective is to type:
- just type `k` for `sudo kubectl` # as need to be sudo for `none` driver
- And at the same type benefit for autocompetion

Equivalent to this in bash:
https://github.com/scoulomb/myk8s/blob/master/Setup/MinikubeSetup/setupBash.sh

#### Install an editor

https://aur.archlinux.org/packages/vim-vi/: `yaourt -Sy vim-vi`.

#### Write fish function for dummies

Locate function here `cd ~/.config/fish`
Source not needed if fish restart
However for function to be sourced at fish start make 1 func per file, with file name == func name

Some basics: https://github.com/razzius/fish-functions/blob/master/functions/any-arguments.fish

#### Basic fish functions

````
echo 'function minikube_reset
   sudo minikube delete
   sudo minikube start --driver=none
   #alias k=\'sudo kubectl\'
end' >  ~/.config/fish/functions/minikube_reset.fish

echo 'function kgpo
   sudo kubectl get pods
end' >  ~/.config/fish/functions/kgpo.fish
````

#### Aliases with autocompletion

##### Auto-completion

I will use the [`kubectl.fish`](https://gist.github.com/terlar/28e1c2e4ac9a27be7a5950306bf45ab2)
And copy it here `~/.config/fish/functions/kubectl.fish`


##### Aliasing

###### Bad solution

This will not work with autocompeltion
````
echo 'function kk
   eval sudo kubectl $argv
end' >  kk.fish

```` 
This needs to ne run every session

````
function k_alias
    alias k='sudo kubectl'
end
````
##### Best solution

From https://gist.github.com/tikolakin/d59b4fc87c0af9720d0d

````
alias k='sudo kubectl'  
funcsave k
````

this will create k.fish

Try 

````
$ vagrant ssh
Last login: Fri May  1 12:13:51 2020 from 10.0.2.2
Welcome to fish, the friendly interactive shell
Type `help` for instructions on how to use fish
[12:20] ~
➤ k get clusters                                                                                              vagrant@archlinuxclusters                  (Resource Type)  limitranges             (Resource Type)  replicationcontrollers  (Resource Type)
componentstatuses         (Resource Type)  namespaces              (Resource Type)  resourcequotas          (Resource Type)
configmaps                (Resource Type)  networkpolicies         (Resource Type)  secrets                 (Resource Type)
daemonsets                (Resource Type)  nodes                   (Resource Type)  serviceaccounts         (Resource Type)
deployments               (Resource Type)  persistentvolumeclaims  (Resource Type)  services                (Resource Type)
endpoints                 (Resource Type)  persistentvolumes       (Resource Type)  statefulsets            (Resource Type)
events                    (Resource Type)  pods                    (Resource Type)  storageclasses          (Resource Type)
horizontalpodautoscalers  (Resource Type)  podsecuritypolicies     (Resource Type)  thirdpartyresources     (Resource Type)
ingresses                 (Resource Type)  podtemplates            (Resource Type)
jobs                      (Resource Type)  replicasets             (Resource Type)
````

Autcompletion is working with aliasing

For clean up may have to perform
`sudo chmod 770 /tmp`.



