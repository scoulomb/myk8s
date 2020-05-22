# Install Minikube on bare metal

My laptop being [repaired](https://github.com/scoulomb/misc-notes/blob/master/repair-laptop-ssd/repair-laptop.md).
I will install minikube.
This can be easily done by applying shell provisionning script in [Vagrant file](./Vagrantfile).

Some modif:
- Insecure certificate is not necessary
- Install curl
- minikube is directly accessible (not vagrant ssh)
- I recommend to not sepecify version when instaling Kubectl to get `1.18` which has several API change as seen in [Master Kubectl section](../../Master-Kubectl/0-kubectl-run-explained.md).
- I recommend to use `sudo -s` when doing the setup 
- As using none driver we need to be sudo when starting minikube and running usual cmd (same in VM)
