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
cd /c/git_pub/myk8s/Setup/MinikubeSetup
vagrant up
vagrant ssh 
````

The command takes a while to run the first time


See usage in [cluster setup](../ClusterSetup/README.md)