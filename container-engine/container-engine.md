# Container engines/runtimes

 
This post on Kubernetes:
https://tanzu.vmware.com/content/blog/kubernetes-for-product-managers (Declarative configuration)

have several key take away:
- Declarative config, model and API (see here https://github.com/scoulomb/myDNS/blob/master/4-Analysis/3-d-other.md)
- We saw the cloud controller (https://kubernetes.io/docs/concepts/architecture/cloud-controller) which in particular configures external lb.
- And also that container engine/runtime was generic, we will deep dive into that here

## Minikube driver 

Driver for Minikube can be docker and Podman, use `--vm-driver=podman`.
From https://v1-18.docs.kubernetes.io/docs/tasks/tools/install-minikube/

````shell script
sudo minikube start --vm-driver=none
<=> by default
sudo minikube start --vm-driver=none --container-runtime=docker
````

#### To not confuse with container runtime

Podman is supported as vm driver but not as container runtime in current Minikube

From https://minikube.sigs.k8s.io/docs/handbook/config/#runtime-configuration

The default container runtime in Minikube is Docker. You can select it explicitly by using:

````shell script
minikube start --container-runtime=docker
````

Other options available are:

- containerd
- cri-o

Same run time as official container runtime described here: https://kubernetes.io/docs/setup/production-environment/container-runtimes/

From: https://towardsdatascience.com/its-time-to-say-goodbye-to-docker-5cfec8eff833
> runc is the most popular container runtime created based on OCI container runtime specification. 
It’s used by Docker (through containerd), Podman and CRI-O, so pretty much everything expect for LXD (which uses LXC). 


Also from same site

> There are other container engines besides Docker and Podman, but I would consider all of them a dead-end tech or not a suitable option for local development and usage. But to have a complete picture, let’s at least mention what’s out there:

Note container engines = runtimes 

> - LXD — LXD is container manager (daemon) for LXC (Linux Containers). This tool offers ability to run system containers that provide container environment that is more similar to VMs. It sits in very narrow space and doesn’t have many users, so unless you have very specific use case, then you’re probably better off using Docker or Podman.
> - CRI-O — When you google what is cri-o, you might find it described as container engine. It really is container runtime, though. Apart from the fact that it isn’t actually an engine, it also is not suitable for “normal” use. And by that I mean that it was specifically built to be used as Kubernetes runtime (CRI) and not for an end-user usage.
> - rkt — rkt (“rocket”) is container engine developed by CoreOS. This project is mentioned here really just for completeness, because the project ended and its development was halted — and therefore it should not be used.

rkt could be used to replace docker (k8s in action),

It is advised to use cri-o as container runtime with podman driver.

If I summarized 

````shell script
Docker ---use---> containerd --use---> runc
CRI-O  ---use------------------------> runc
Podman ---use------------------------> runc
LXD    ---use------------------------> LXC
````


### Kubernetes will deprecate Docker!

They will allow only 

- containerd
-  cri-o

Why?
From k8s blog: https://kubernetes.io/blog/2020/12/02/dont-panic-kubernetes-and-docker/

| Container engine                 | Produces OCI compliant | is CRI              | 
|----------------------------------|------------------------|----------------------|
| (Shim ->) Docker -> containerd   | YES                    | YES                  |
| (Shim ->) containerd             | YES                    | YES                  |
| (Shim ->) CRI-O                  | YES                    | YES                  |
| Podman                           | YES                    | YES                  |


See what it means to be CRI: https://github.com/kubernetes/community/blob/master/contributors/devel/sig-node/container-runtime-interface.md

To make Docker CRI-O (which is need to work with Kubernetes), they have to maintain docker shim.
Whereas they just need the docker engine part which is contenaird.

To avoid to maintain shim, they will only allow:

- containerd
-  cri-o


Quoting blog:
> Docker isn’t compliant with CRI, the Container Runtime Interface. If it were, we wouldn’t need the shim, and this wouldn’t be a thing. But it’s not the end of the world, and you don’t need to panic -- you just need to change your container runtime from Docker to another supported container runtime.

But as Docker produce OCI compliant image, those engine (contenaird, cri-o) will be able to run Docker image.

contenaird and cri-o seems to have a shim from [Services\appendix_internals.md](../Services/appendix_internals.md#what-happens-when-i-do-kubectl-exec).
but they seem to embed it directly.

>  The image that Docker produces isn’t really a Docker-specific image -- it’s an OCI (Open Container Initiative) image. Any OCI-compliant image, regardless of the tool you use to build it, will look the same to Kubernetes. Both containerd and CRI-O know how to pull those images and run them. This is why we have a standard for what containers should look like.

From https://microtica.com/blog/kubernetes-is-deprecating-docker-support/

1. https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.20.md#deprecation

````shell script
Docker support in the kubelet is now deprecated and will be removed in a future release.
The kubelet uses a module called "dockershim" which implements CRI support for Docker and
it has seen maintenance issues in the Kubernetes community. 
We encourage you to evaluate moving to a container runtime that is a full-fledged implementation of CRI (v1alpha1 or v1 compliant)
as they become available. (#94624, @dims) [SIG Node]
````
1.  https://kubernetes.io/docs/setup/production-environment/container-runtimes/

Docker will be removed there

1. https://kubernetes.io/blog/2020/12/02/dont-panic-kubernetes-and-docker/


### Playing with podman

Access gcr docker (google container registry, where we pushed image with docker) via Podman 

````shell script
gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin eu.gcr.io
https://stackoverflow.com/questions/63790529/authenticate-to-google-container-registry-with-podman
podman search eu.gcr.io/covid
````

Build docker image and then run it via Podman

````shell script
sylvain@sylvain-hp:~/podmantst$ sudo docker build .
Sending build context to Docker daemon  2.048kB
 ---> 1d622ef86b13
Step 2/2 : CMD ["echo", "hello"]
 ---> Running in b627cfd28823
Removing intermediate container b627cfd28823
 ---> 4473d457755e
Successfully built 4473d457755e
sylvain@sylvain-hp:~/podmantst$ sudo docker build . -t myhello
Sending build context to Docker daemon  2.048kB
Step 1/2 : FROM ubuntu
 ---> 1d622ef86b13
Step 2/2 : CMD ["echo", "hello"]
 ---> Using cache
 ---> 4473d457755e
Successfully built 4473d457755e
Successfully tagged myhello:latest
sylvain@sylvain-hp:~/podmantst$ sudo podman run docker-daemon:myhello
Error: unable to pull docker-daemon:myhello: docker-daemon: reference myhello has neither a tag nor a digest
sylvain@sylvain-hp:~/podmantst$ sudo podman run docker-daemon:myhello:latest
Getting image source signatures
Copying blob 8891751e0a17 done
Copying blob 2a19bd70fcd4 done
Copying blob 9e53fd489559 done
Copying blob 7789f1a3d4e9 done
Copying config 4473d45775 done
Writing manifest to image destination
Storing signatures
hello
sylvain@sylvain-hp:~/podmantst$ sudo podman run myhello
hello
sylvain@sylvain-hp:~/podmantst$ cat Dockerfile
FROM ubuntu
CMD ["echo", "hello"]
````

Interoperable registry, this shows OCI compliance.
<!-- ok not using docker-doctor -->


Also from: https://developers.redhat.com/blog/2019/02/21/podman-and-buildah-for-docker-users/
When you first type podman images, you might be surprised that you don’t see any of the Docker images you’ve already pulled down. 
This is because Podman’s local repository is in /var/lib/containers instead of /var/lib/docker.  This isn’t an arbitrary change; this new storage structure is based on the Open Containers Initiative (OCI) standards.

We have in Podman the concept of pod (with several container, like side-car)!

See [here more details on container engine](../Services/appendix_internals.md).



