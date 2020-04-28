# My k8s

This repo is my personal Kubernetes playground.

Here are covered topics:

- [Setup a cluser](./Setup) in a VM with Vagrant and local registry 
    - Using [real cluster setup](./Setup/ClusterSetup/README.md) or with [Minikube](./Setup/MinikubeSetup/README.md).
    - Note: For registry we can:
        - Deploy a local registry 
        - Use Dockerhub (not tested) or corporate registry...
        - But it can be bypassed if using `image pull policy` set to `never` and build the image on the node.
        - Example can be found in [Security section](./Security/0-capabilities-bis-part1-basic.md).
- [Deployment](./Deployment/basic.md)
- [Volume](./Volumes/fluentd-tutorial.md)
- [Services and exposing an application](./Services/service_deep_dive.md) 
- [Security](./Security/0-capabilities-bis-part1_test.sh)
    - [Capabilities](./Security/0-capabilities-bis-part1_test.sh)
    - [Secret](./Security/1-secret-creation-consumption.md)
    - [Service account](./Security/2-service-account.md)
    - [Network policy](./Security/3-1-network-policy-NoPolicy.md)