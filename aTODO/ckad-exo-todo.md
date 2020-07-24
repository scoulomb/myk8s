# CKAD exo final TODO

https://github.com/scoulomb/ckad-exo-private

## OK
* puis A - doc only (now can consider OK except cheatsheet, see status at top of a file), exo done
(b-f section exo + doc done !)
* Schedule test OK, handbook read OK,
* context, kube config => JUGE OK
* Move section f OK CLEAR: https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/4-Run-instructions-into-a-container.md
* 1/06 hp@ubuntu 1.18: tmux (ctrl insert, shift insert pour copy/paste) : https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/tmux.md OK
* 1/06 hp@ubuntu 1.18: k run restart in v1.18: clarified here: https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/1-kubectl-create-explained-ressource-derived-from-pod.md OK
* 1/06 hp@ubuntu 1.18 (for kube versin use hp laptop) kubectl autocompletion: https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/autocompletion.md
Same as hidden comment in k run use hp OK
Include in cheatsheet if think on it OK, this autocompletin does not work in fish, 
compare command in k run from memory OK
* 1/06 deployment k expose OK
https://github.com/scoulomb/myk8s/blob/7dc0bfadf36a0104bf974fb62156d626fdef5d6c/Deployment/advanced/container-port.md
https://github.com/scoulomb/myk8s/blob/7dc0bfadf36a0104bf974fb62156d626fdef5d6c/Deployment/advanced/container-port.md#using-kubectl-create-deployment
and k apply mention in myk8s particular case: https://github.com/dgkanatsios/CKAD-exercises/blob/master/c.pod_design.md#create-a-deployment-with-image-nginx178-called-nginx-having-2-replicas-defining-port-80-as-the-port-that-this-container-exposes-dont-create-a-service-for-this-deployment
(see comment in my fork of CKAD exo)
Tested exopose on a pod directly use label (for instance run)
Same here for sure: https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/article.md#create-a-service-to-deploy-the-pod OK
Same comment with pod: https://github.com/scoulomb/myk8s/blob/master/Deployment/advanced/container-port.md#using-kubectl-create-deployment => If we do not patch with containerPort we should do
````shell script
k run test2 --image=alpine --restart=Never # From autocmpletion OK
k expose po test2 --port=80 
````
==> OK
* access to multiple cluster quicly line book ok 
gcloud also auto config OK
* Bookmarks OK  (imported in git)

* 1/06 Do ideas in cheatsheet (voir master kubectl  ideas md, section f)!
(cheatsheet just copy past +cm/secret -> not that useful in the end?)
extended suffit ou faire summary
linux academy cheatsheet
DONE: https://github.com/scoulomb/myk8s/blob/master/Master-Kubectl/cheatsheet.md

Not retested in ubuntu but copy/paste 
consistency should be ok, delete stuff but relies on stuff before 
No double check OK

## KO


- next in master kubectl folder and current.md in myk8s
* Luska: operator, staeful set (questions)
* microsoft ckad
* current
* kbe config move to myk8s repo mais ca archive work (ext)

OKOK STOP OKOK
======

https://linuxacademy.com/course/docker-certified-associate-dca/

pr merge but ip genration duplcated to fix?

===
After tst voir note
CKAD notes (ext)
complete cheat sheet with secret and CM/secret

practise:
LXA practise test 
https://github.com/jbigtani/crack-CKAD => 150 practise
https://medium.com/@sensri108/practice-examples-dumps-tips-for-cka-ckad-certified-kubernetes-administrator-exam-by-cncf-4826233ccc27


--
some notes end of section CKAD, more improvements of k8s doc, not part of TODO
Interesting content moved to myk8s OK
ssh come back

LXA

Netowork policies (ns scope but can have ns selector) OK
- Step 1: client -> secured pod OK
- Step 2: Add network policy slelecting secured pod (spec.podSelector.matchLabel) and prevent ingress except from pod with a given label (spec.ingress.from.podsselectors.matchlabels)
=> qd pod selectionne Network policy (label) it applies to it and need to white
A pod can be selected by sveral network policy and in that case we do an union of whitelist 
Thus defaut deny all: https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-traffic
pattern 
Not tested buy can also allow all: https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-allow-all-ingress-traffic
- Step 3: client -> secured pod KO
- Step 4: Add label to client pod to match spec.ingress.from.podsselectors.matchlabels
- Step 5: client -> secured pod OK

equivalent here: https://github.com/scoulomb/myk8s/blob/master/Security/3-4-network-policy-RelaxingPolicy.md
But less explicit -> suffit 

k get networkpolicy return selectorallowed ouf ca eu ca a exam 
et aouter du coup au pod (vor ckad note)

````
k get network policySS
NAME           POD-SELECTOR      AGE
access-db      app=db            13h
access-web     app=web   
````

du coup inagine que pod protege est db et web et ajouter au pod client label ds pod selector
D ailleurs il le dit

Autre policy peut etre deny all OK

Intro -> creation pod 
Coudl create cluster 
Repondu question dans pod creation betweek k apply et create 
si kcreate on existing resource fail OK

/-> study guide from lxa pdf very good also