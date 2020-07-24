End of [259 file](../ama-private/current.md) (with more general point)

- Que lab 8 et ch 8 de lFD259 Not done

- Headless service (only remaining on svc topic ) and optional
https://kubernetes.io/fr/docs/concepts/services-networking/service/#headless-services
"I assume OpenShift route is the Alternative" in [service deep dive](./Services/service_deep_dive.md) -> OK

## Links

- https://gist.github.com/veggiemonk/70d95df77029b3ebe58637d89ef83b6b\
- https://www.youtube.com/watch?v=HwogE64wjmw
- https://docs.google.com/document/d/1qSY_keLNdOo53258wgV3eUjv-VxlR-qgsRmyXVxsRAo/edit#heading=h.1efzpwwrxlvu
- https://stackoverflow.com/questions/45279572/how-to-start-a-pod-in-command-line-without-deployment-in-kubernetes
- https://github.com/dgkanatsios/CKAD-exercises/blob/master/c.pod_design.md
- https://devblogs.microsoft.com/premier-developer/astuces-pour-reussir-votre-certification-ckad-certified-kubernetes-application-developer/
- k8s in action
- coursera gcp platform free courses

## Exploration / TODO
- VM link - new laptop ok for k8s
    - setup VM [ici](../Setup/ArchDevVM/archlinux-dev-vm-with-minikube.md)
    - commit myk8s ok and custom br dev_vm (vim) OK 
    - provisioning fater: Total run time:  804.324 s FIXED CONNEXION
    - This commit all OK: https://github.com/scoulomb/myk8s/commit/06f06617875d13ba46e3e78d535ec2b6722af059, improve dns osef
TODO- reprovision and test editor: error to timeout internet ok and k run and k edit
```
➤ k run alpine --image alpine --restart=Never -- /bin/sleep 10                                                                                                                vagrant@archlinux
pod/alpine created                                                                                                                                                                       vagrant@archlinux
[18:14] ~
➤ k edit pod alpine                                                                                                                                                           vagrant@archlinux
error: unable to launch the editor "vi"
[18:14] ~
➤ echo $KUBE_EDITOR                                                                                                                                                           vagrant@archlinux
vim
[18:14] ~
```
so to be fixed with doc, meanwhile 
sudo pacman -S vi
it was the second version with last update which was tested here ok-lien todo ok
TODO    - SSH issue balabit
TODO    - minikubedasboard -> create copy of svc to nodeport


- [security 3-4](../Security/3-4-network-policy-RelaxingPolicy.md#SEC-status),  pointing to [Here](0-capabilities-bis-part3-psp-tutorial.md#status)
Nothing to understand -More to contribute
[OpenIssue]   --resource=podsecuritypolicies.extensions => OK in last kubectl version

- [use volume rather than chmod CONSIDER DONE YES](./0-capapbilies-bis-part5) 

- Make volume link k8s in action p213 (cm refresh)/281 
https://stackoverflow.com/questions/61533348/kubernetes-hostpath-volume-behaviour-on-a-cluster-with-nore-than-one-node

-  https://github.com/dgkanatsios/CKAD-exercises

- Steps defined [here](../Master-Kubectl/next.md) (0,1,2 are ok)
[Open issue]

- Go quick
https://github.com/dgkanatsios/CKAD-exercises
cheatsheet et aller vite
https://medium.com/bb-tutorials-and-thoughts/practice-enough-with-these-questions-for-the-ckad-exam-2f42d1228552

=> master kubectl create cm/secret

+ section f (qui est ok) avec k run etc...

- gmail kube from thu end of apro

- https://kubernetes.io/docs/reference/kubectl/cheatsheet/ 
Double quote issue and EOF understand
use bash
https://stackoverflow.com/questions/22697688/how-to-cat-eof-a-file-containing-code/22698106
and - is a convetion to read out 
k apply -f -
and in here doc

8/05: ALL IS Here for k8s!
UPDATE GIT + HERE OKOKOK

+- Luska
+
+write controller and stateful set question
+
+oldgist
