 ## PR 25027 and derivative

https://github.com/kubernetes/website/pull/25027
https://github.com/kubernetes/website/pulls?q=is%3Apr+is%3Aclosed+author%3Ascoulomb => 3 PR in Nov/Dec


<!--
I had some issue when cloning k8s website thus made PR online
when needed to update wanted to fetch 
https://stackoverflow.com/questions/9537392/git-fetch-remote-branch
But same issue in different machine when cloning
But trying with github desktop via link in html gui,
selecting branch created online, open file in vs code integration, update and then open terminal and use normal command to amend
I could also have used Podman for online edition
-->
  
### Initial version of 25027

````shell script
### v1
title: Consumed secret values from environment variables are not updated automatically
When a secret value currently consumed from environment variable is updated, container's environment variable will not be updated.
Environment variable will be updated if the container is restarted by the kubelet.

### v2
title: Consumed secret values from environment variables are not updated automatically
If a container already consumed a secret value from environment variable, a secret update will not cascade update to the  containrer.    

Environment variable will be updated if the container is restarted by the kubelet.

=> by envFrom did not try but pretty sure key are also not updated, and would be present if kubelet is restart 
=> already because when not defined error as seen here

### v3 (pr initial version)
title:  Environment variables are not updated after a secret update

If a container already consumed a secret in an environment variable, secret update will not cascade update to the container.
But if the Kubelet restarts the container, secret update will be available.
=> if pod deleted and restarted it is obvious we have the update  
````

### and then modified from comments


#### Change based on Jiehong comments (16/11)
Note: in https://github.com/scoulomb/myk8s/blob/master/Volumes/secret-doc-deep-dive.md we mention initial phrasing,
I remove the Kubelet but it is still valid.

#### based on kbhawkey (17/11)

See [section Can we update environment var when not using a secret?](secret-doc-deep-dive.md#can-we-update-environment-var-when-not-using-a-secret)

#### Based on stfim 

See [section Third party solutions for triggering restarts when ConfigMaps and Secrets change](#third-party-solutions-for-triggering-restarts-when-configmaps-and-secrets-change).

#### Based on tgqm

phrasing OK


<!-- when doing pr in my k8s could have one update branch we rebase everytime -->


### Could make similar for ConfigMap?

but harder to insert in doc: https://kubernetes.io/docs/concepts/configuration/configmap/ so no
made assumption same behavior as secret which I will not verify then
and about consumption mode mentioned in cm doc, consider aligned:
https://github.com/scoulomb/myk8s/blob/master/Volumes/volume4question.md#4-configmap-consumption

### Do not use docker specific wording (new PR: https://github.com/kubernetes/website/pull/25068)

And the 4 ways to use a cm described here https://kubernetes.io/docs/concepts/configuration/configmap/
- Command line arguments to the entrypoint of a container
- Environment variables for a container
- Add a file in read-only volume, for the application to read
- Write code to run inside the Pod that uses the Kubernetes API to read a ConfigMap
aligned with https://github.com/scoulomb/myk8s/blob/master/Volumes/volume4question.md#4-configmap-consumption
"Write code to run inside the Pod that uses the Kubernetes API to read a ConfigMap" is "Can be used by system components and controller (k8s controller)"

But For "Command line arguments to the entrypoint of a container" it would be more accurate to say pod commands
Since as seen in [part d](https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-d.md): Docker `ENTRYPOINT` <=> k8s `command`

Moreover 
- From https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#define-a-command-and-arguments-when-you-create-a-pod
> Note: The command field corresponds to entrypoint in some container runtimes. Refer to the Notes below.

Also Here https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#notes
rules are mentionned and same as docker in particular:
> If you supply a command (<-> docker ENTRYPONT) but no args (<-> docker CMD) for a Container, only the supplied command is used. 
> The default EntryPoint and the default Cmd defined in the Docker image are ignored.
(here they mention Docker so fine)
is equivalent to this note in docker doc

https://docs.docker.com/engine/reference/run/#entrypoint-default-command-to-execute-at-runtime

> Passing --entrypoint will clear out any default command set on the image (i.e. any CMD instruction in the Dockerfile used to build it).
(note command -. Docker CMD)

See here [part d](https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-d.md#override-entrypoint-and-command) and fact we ue exec form.

Here
https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#notes
array similar to Docker but not the same details, skipped

https://docs.docker.com/engine/reference/builder/#entrypoint
-> The shell form prevents any CMD or run command line arguments from being used,
CMD [“p1_cmd”, “p2_cmd”] + ENTRYPOINT exec_entry p1_entry (shell from)
CMD exec_cmd p1_cmd      + ENTRYPOINT exec_entry p1_entry (shel form)
leads to /bin/sh -c exec_entry p1_entry

-From: https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#use-configmap-defined-environment-variables-in-pod-commands
> You can use ConfigMap-defined environment variables in the command section of the Pod specification using the $(VAR_NAME) Kubernetes substitution syntax.

(note the special synthax)

Thus I would propose a new PR here to say
"Inside a Pod command": https://github.com/kubernetes/website/pull/25068


### New PR for shell expansion (see Note on exec from and Kubernetes shell expansion)

See https://github.com/scoulomb/myDNS/blob/master/2-advanced-bind/5-real-own-dns-application/6-use-linux-nameserver-part-d-other-applications.md#note-on-exec-from-and-kubernetes-shell-expansion

- https://github.com/kubernetes/website/pull/25068
- https://github.com/kubernetes/website/pull/25089
