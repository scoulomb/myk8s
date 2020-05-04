# Setup a local Kubernetes cluster and artifactory/docker hub

## Prerequisite

Prepare Windows to host VM

0. Request admin rigth for the PC (service catalog ticket), and sync one drive
1. Install NPP++: https://notepad-plus-plus.org/downloads,
2. Install virtual box: https://download.virtualbox.org/virtualbox/6.1.6/VirtualBox-6.1.6-137129-Win.exe,
3. Install vagrant: https://www.vagrantup.com/downloads.html,
4. Install Jetbrain toolbox: and from there install pycharm ce and pro (do not choose a rc),
5. Install conemu https://conemu.github.io/en/Downloads.html,
6. Install git (select lf for line separator, cf. issue [here](./fix-line-speparator-issue.md)),

*Note*: Git is needed to clone DEV VM and for repo which are not in the Vagrant sync path. More [git details](../Repo-mgmt/repo-mgmt.md).
You can copy this [`gitconfig`](https://github.com/scoulomb/dev_vm/blob/custom/saltstack/salt/common/git/gitconfig) made in [ArchDevVM](./ArchDevVM/archlinux-dev-vm-with-minikube.md) using RAW: 
`curl --insecure https://raw.githubusercontent.com/scoulomb/dev_vm/custom/saltstack/salt/common/git/gitconfig?token=$TOKEN > ~/.gitconfig`
You may have to comment `diff-so-fancy`.

## Cluster setup

This VM are depoyed using Vagrant and based on Ubuntu.

- [Real cluster setup](./Setup/ClusterSetup/README.md) with `kubeadm`
- Or with [Minikube](./Setup/MinikubeSetup/README.md)

Alternatively we can configure Archlinux DEV VM with minikube.
This is explained in this [document](ArchDevVM/archlinux-dev-vm-with-minikube.md).

## Registry setup

For registry we can:
- Deploy a local registry (done in [clusterSetup](./ClusterSetup))
- Use Dockerhub (not tested) or corporate registry...
- But it can be bypassed if using `image pull policy` set to `never` and build the image on the node.

Example can be found in [Security section](./../Security/0-capabilities-bis-part1-basic.md) and matching section in private folder.
