# Network policy


## Releasing policy

Rather than targeting service from node, as always working in our VM setup.
- We will take pod intercommunication as in [section 3.2](3-2-network-policy-NoPolicySummary.md#pod-to-pod-communication)
- egress to mozilla.org as in section [section 3.3](3-2-network-policy-NoPolicySummary.md#egress)

````buildoutcfg
$ k exec -it -c busy app -- nc -vz www.mozilla.org 80
````

## Allowing all egress traffic

````buildoutcfg
echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: custom-network-policy
spec: 
  podSelector: {}
  policyTypes:
  - Ingress 
  # - Egress
'> deny-all.yaml

k replace -f deny-all.yaml
````

Output is

````buildoutcfg
vagrant@k8sMaster:~
$ k exec -it -c busy app -- nc -vz www.mozilla.org 80
www.mozilla.org (104.16.142.228:80) open
````

==> it is now open again unlike [3.3](3-3-network-policy-AddingDenyAllPolicy.md#egress)
(<=> 6.5.6)
````
vagrant@k8sMaster:~
$ ./interpod-com-test-ping.sh
++ echo -e '\n-- Internal DNS (Service ip)\n'

-- Internal DNS (Service ip)

++ kubectl exec -it -c busy newapp -- ping -c 5 app
PING app (10.103.90.128): 56 data bytes

--- app ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
command terminated with exit code 1
++ echo -e '\n-- Service env var (service IP) \n'

-- Service env var (service IP)

++ echo 'ping -c 5 $APP_SERVICE_HOST'
++ kubectl cp /home/vagrant/testping.sh newapp:/tmp/testping.sh -c busy
++ kubectl exec -it -c busy newapp -- chmod u+x /tmp/testping.sh
++ kubectl exec -it -c busy newapp -- bin/sh /tmp/testping.sh
PING 10.103.90.128 (10.103.90.128): 56 data bytes

--- 10.103.90.128 ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
command terminated with exit code 1
++ echo -e '\n-- POD IP directly \n'

-- POD IP directly

+++ kubectl get pods -o wide
+++ awk '{ print $6 }'
+++ grep '^app'
++ export APP_POD_IP=192.168.16.188
++ APP_POD_IP=192.168.16.188
++ echo 192.168.16.188
192.168.16.188
++ export 'cmd=ping -c 3 192.168.16.188'
++ cmd='ping -c 3 192.168.16.188'
++ kubectl exec -it -c busy newapp -- ping -c 3 192.168.16.188
PING 192.168.16.188 (192.168.16.188): 56 data bytes

--- 192.168.16.188 ping statistics ---
3 packets transmitted, 0 packets received, 100% packet loss
command terminated with exit code 1
++ echo -e '\n-- app to app \n'

-- app to app

++ kubectl exec -it -c busy app -- ping -c 3 app
PING app (192.168.16.188): 56 data bytes
64 bytes from 192.168.16.188: seq=0 ttl=64 time=0.032 ms
64 bytes from 192.168.16.188: seq=1 ttl=64 time=0.053 ms
64 bytes from 192.168.16.188: seq=2 ttl=64 time=0.034 ms

--- app ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.032/0.039/0.053 ms

````

Here for interpod there was no change because even if egress is allowed, we target another pod.
The ingress of the other pod is still closed.

## Allow ingress coming from an IP range

All pod are deployed in IP range `192.168.0.0/16`.
This is what we saw in [section 3.2](3-2-network-policy-NoPolicySummary.md#get-pod-id).(<=> 6.5.6)


So we can add a selector to allow ingress from this range:


````buildoutcfg
echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: custom-network-policy
spec: 
  podSelector: {}
  policyTypes:
  - Ingress 
  # - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 192.168.0.0/16
'> deny-all.yaml

k replace -f deny-all.yaml
````

Output is:

````buildoutcfg
vagrant@k8sMaster:~
$ ./interpod-com-test.sh
++ echo -e '\n-- Internal DNS (Service ip)\n'

-- Internal DNS (Service ip)

++ kubectl exec -it -c busy newapp -- nc -vz app 80
app (10.103.90.128:80) open
++ head -n 6
++ kubectl exec -it -c busy newapp -- wget -O - app
Connecting to app (10.103.90.128:80)
writing to stdout
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
++ echo -e '\n-- Service env var (service IP) \n'

-- Service env var (service IP)

++ echo 'nc -vz $APP_SERVICE_HOST $APP_SERVICE_PORT'
++ kubectl cp /home/vagrant/test.sh newapp:/tmp/test.sh -c busy
++ kubectl exec -it -c busy newapp -- chmod u+x /tmp/test.sh
++ kubectl exec -it -c busy newapp -- bin/sh /tmp/test.sh
10.103.90.128 (10.103.90.128:80) open
++ echo -e '\n-- POD IP directly \n'

-- POD IP directly  (<-- <=> 6.5.9 where reuse ip in 6.5.6)

+++ grep '^app'
+++ awk '{ print $6 }'
+++ kubectl get pods -o wide
++ export APP_POD_IP=192.168.16.188
++ APP_POD_IP=192.168.16.188
++ echo 192.168.16.188
192.168.16.188
++ export 'cmd=nc -vz 192.168.16.188 80'
++ cmd='nc -vz 192.168.16.188 80'
++ kubectl exec -it -c busy newapp -- nc -vz 192.168.16.188 80
192.168.16.188 (192.168.16.188:80) open
++ echo -e '\n-- app to app \n'

-- app to app

++ kubectl exec -it -c busy app -- nc -vz app 80
app (192.168.16.188:80) open

vagrant@k8sMaster:~
$ ./interpod-com-test-ping.sh
++ echo -e '\n-- Internal DNS (Service ip)\n'

-- Internal DNS (Service ip)

++ kubectl exec -it -c busy newapp -- ping -c 5 app
PING app (10.103.90.128): 56 data bytes

--- app ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
command terminated with exit code 1
++ echo -e '\n-- Service env var (service IP) \n'

-- Service env var (service IP)

++ echo 'ping -c 5 $APP_SERVICE_HOST'
++ kubectl cp /home/vagrant/testping.sh newapp:/tmp/testping.sh -c busy
++ kubectl exec -it -c busy newapp -- chmod u+x /tmp/testping.sh
++ kubectl exec -it -c busy newapp -- bin/sh /tmp/testping.sh
PING 10.103.90.128 (10.103.90.128): 56 data bytes

--- 10.103.90.128 ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
command terminated with exit code 1
++ echo -e '\n-- POD IP directly \n'

-- POD IP directly

+++ kubectl get pods -o wide
+++ grep '^app'
+++ awk '{ print $6 }'
++ export APP_POD_IP=192.168.16.188
++ APP_POD_IP=192.168.16.188
++ echo 192.168.16.188
192.168.16.188
++ export 'cmd=ping -c 3 192.168.16.188'
++ cmd='ping -c 3 192.168.16.188'
++ kubectl exec -it -c busy newapp -- ping -c 3 192.168.16.188
PING 192.168.16.188 (192.168.16.188): 56 data bytes
64 bytes from 192.168.16.188: seq=0 ttl=63 time=0.073 ms
64 bytes from 192.168.16.188: seq=1 ttl=63 time=0.106 ms
64 bytes from 192.168.16.188: seq=2 ttl=63 time=0.164 ms

--- 192.168.16.188 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.073/0.114/0.164 ms
++ echo -e '\n-- app to app \n'

-- app to app

++ kubectl exec -it -c busy app -- ping -c 3 app
PING app (192.168.16.188): 56 data bytes
64 bytes from 192.168.16.188: seq=0 ttl=64 time=0.036 ms
64 bytes from 192.168.16.188: seq=1 ttl=64 time=0.048 ms
64 bytes from 192.168.16.188: seq=2 ttl=64 time=0.082 ms

--- app ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.036/0.055/0.082 ms
vagrant@k8sMaster:~

````

We reach same output as [section 3.2 when there was no policy](3-2-network-policy-NoPolicySummary.md#Pod to pod communication).



## Ping - not TCP

We add port and protocol to block the ping.

````buildoutcfg
echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: custom-network-policy
spec: 
  podSelector: {}
  policyTypes:
  - Ingress 
  # - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 192.168.0.0/16
    ports:
    - port: 80
      protocol: TCP
  
'> deny-all.yaml

k replace -f deny-all.yaml
````

Output is:

````buildoutcfg
vagrant@k8sMaster:~                                                                                                                                                                     
$ ./interpod-com-test.sh                                                                                                                                                                
++ echo -e '\n-- Internal DNS (Service ip)\n'                                                                                                                                           
                                                                                                                                                                                        
-- Internal DNS (Service ip)                                                                                                                                                            
                                                                                                                                                                                        
++ kubectl exec -it -c busy newapp -- nc -vz app 80                                                                                                                                     
app (10.103.90.128:80) open                                                                                                                                                             
++ kubectl exec -it -c busy newapp -- wget -O - app                                                                                                                                     
++ head -n 6                                                                                                                                                                            
Connecting to app (10.103.90.128:80)                                                                                                                                                    
writing to stdout                                                                                                                                                                       
<!DOCTYPE html>                                                                                                                                                                         
<html>                                                                                                                                                                                  
<head>                                                                                                                                                                                  
<title>Welcome to nginx!</title>                                                                                                                                                        
++ echo -e '\n-- Service env var (service IP) \n'                                                                                                                                       
                                                                                                                                                                                        
-- Service env var (service IP)                                                                                                                                                         
                                                                                                                                                                                        
++ echo 'nc -vz $APP_SERVICE_HOST $APP_SERVICE_PORT'                                                                                                                                    
++ kubectl cp /home/vagrant/test.sh newapp:/tmp/test.sh -c busy                                                                                                                         
++ kubectl exec -it -c busy newapp -- chmod u+x /tmp/test.sh                                                                                                                            
++ kubectl exec -it -c busy newapp -- bin/sh /tmp/test.sh                                                                                                                               
10.103.90.128 (10.103.90.128:80) open                                                                                                                                                   
++ echo -e '\n-- POD IP directly \n'                                                                                                                                                    
                                                                                                                                                                                        
-- POD IP directly                                                                                                                                                                      
                                                                                                                                                                                        
+++ awk '{ print $6 }'                                                                                                                                                                  
+++ grep '^app'                                                                                                                                                                         
+++ kubectl get pods -o wide                                                                                                                                                            
++ export APP_POD_IP=192.168.16.188                                                                                                                                                     
++ APP_POD_IP=192.168.16.188                                                                                                                                                            
++ echo 192.168.16.188                                                                                                                                                                  
192.168.16.188                                                                                                                                                                          
++ export 'cmd=nc -vz 192.168.16.188 80'                                                                                                                                                
++ cmd='nc -vz 192.168.16.188 80'                                                                                                                                                       
++ kubectl exec -it -c busy newapp -- nc -vz 192.168.16.188 80                                                                                                                          
192.168.16.188 (192.168.16.188:80) open                                                                                                                                                 
++ echo -e '\n-- app to app \n'                                                                                                                                                         
                                                                                                                                                                                        
-- app to app                                                                                                                                                                           
                                                                                                                                                                                        
++ kubectl exec -it -c busy app -- nc -vz app 80                                                                                                                                        
app (192.168.16.188:80) open                                                                                                                                                            


vagrant@k8sMaster:~
$ ./interpod-com-test-ping.sh
++ echo -e '\n-- Internal DNS (Service ip)\n'

-- Internal DNS (Service ip)

++ kubectl exec -it -c busy newapp -- ping -c 5 app
PING app (10.103.90.128): 56 data bytes

--- app ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
command terminated with exit code 1
++ echo -e '\n-- Service env var (service IP) \n'

-- Service env var (service IP)

++ echo 'ping -c 5 $APP_SERVICE_HOST'
++ kubectl cp /home/vagrant/testping.sh newapp:/tmp/testping.sh -c busy
++ kubectl exec -it -c busy newapp -- chmod u+x /tmp/testping.sh
++ kubectl exec -it -c busy newapp -- bin/sh /tmp/testping.sh
PING 10.103.90.128 (10.103.90.128): 56 data bytes

--- 10.103.90.128 ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
command terminated with exit code 1
++ echo -e '\n-- POD IP directly \n'

-- POD IP directly

+++ kubectl get pods -o wide
+++ grep '^app'
+++ awk '{ print $6 }'
++ export APP_POD_IP=192.168.16.188
++ APP_POD_IP=192.168.16.188
++ echo 192.168.16.188
192.168.16.188
++ export 'cmd=ping -c 3 192.168.16.188'
++ cmd='ping -c 3 192.168.16.188'
++ kubectl exec -it -c busy newapp -- ping -c 3 192.168.16.188
PING 192.168.16.188 (192.168.16.188): 56 data bytes

--- 192.168.16.188 ping statistics ---
3 packets transmitted, 0 packets received, 100% packet loss
command terminated with exit code 1
++ echo -e '\n-- app to app \n'

-- app to app

++ kubectl exec -it -c busy app -- ping -c 3 app
PING app (192.168.16.188): 56 data bytes
64 bytes from 192.168.16.188: seq=0 ttl=64 time=0.048 ms
64 bytes from 192.168.16.188: seq=1 ttl=64 time=0.045 ms
64 bytes from 192.168.16.188: seq=2 ttl=64 time=0.041 ms

--- app ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.041/0.044/0.048 ms
                                                                                                                                                            
````

No change for port 80
However for ping with "pod ip directly"" it is not working anymore unlike previous section.

## Can I use label in instead of CIDR

Yes, in spec.ingress.from I replace cidr by podSelector.
Since going from newapp to app, the `spec.ingress.from` will contain newapp label.

````buildoutcfg
vagrant@k8sMaster:~
$ k describe pod newapp app | grep Labels
Labels:       svc-name=newapp
Labels:       svc-name=app
````

````buildoutcfg
k delete networkpolicies --all

echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: custom-network-policy
spec: 
  podSelector: {}
  policyTypes:
  - Ingress 
  # - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          svc-name: newapp
    ports:
    - port: 80
      protocol: TCP
  
'> deny-all.yaml

k create -f deny-all.yaml
````

If I run `/interpod-com-test.sh`, it will work as CIDR.
What happen if I edit the label of new app.

````buildoutcfg
vagrant@k8sMaster:~
$ k edit pod newapp
pod/newapp edited
````

When running `interpod-com-test.sh`, it fails.

Reverting the change, it works.

## Concurrent net policy

### First try

Here we had one network policy applying to all the pods.

A good practise is to have one rule deny all, with `{}` spec.podSelector.
And white list correct pods, so to have a second network policy 
(root.spec.podSelector set to app, as `newapp->app`).
To whitelist the traffic.
Cf. https://kubernetes.io/docs/concepts/services-networking/network-policies/#networkpolicy-resource.


````buildoutcfg
k delete networkpolicies --all

echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec: 
  podSelector: {}
  policyTypes:
  - Ingress 
  - Egress
'> deny-all.yaml

k create -f deny-all.yaml

echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: whitelist
spec: 
  podSelector:
    matchLabels:
      svc-name: app
  policyTypes:
  - Ingress 
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          svc-name: newapp
    ports:
    - port: 80
      protocol: TCP
  
'> whitelist.yaml

k create -f whitelist.yaml
````

In my test when doing this everything was denied which seems unexpected. (from lfd/luska)

So if doing :

````buildoutcfg
k delete -f deny-all.yaml
````
`interpod-com-test.sh` is working again.

### Fixing it

Understand how it is working.

https://kubernetes.io/docs/concepts/services-networking/network-policies/#isolated-and-non-isolated-pods
> Network policies do not conflict, they are additive. If any policy or policies select a pod, the pod is restricted to what is allowed by the union of those policies’ ingress/egress rules. Thus, order of evaluation does not affect the policy result.

and from there: https://livebook.manning.com/book/kubernetes-in-action/chapter-13/268

As in the book we will remove policyTypes


````buildoutcfg
k delete networkpolicies --all

echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec: 
  podSelector: {}
'> deny-all.yaml

k create -f deny-all.yaml
````
Here `interpod-com-test.sh` will not work.

Adding

````buildoutcfg
echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: whitelist
spec: 
  podSelector:
    matchLabels:
      svc-name: app
  policyTypes:
  - Ingress 
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          svc-name: newapp
    ports:
    - port: 80
      protocol: TCP
  
'> whitelist.yaml

k create -f whitelist.yaml
````

Then `interpod-com-test.sh` is working!


### Why it is working

This is because from the [doc](https://kubernetes.io/docs/concepts/services-networking/network-policies/#networkpolicy-resource).
> If no policyTypes are specified on a NetworkPolicy then by default Ingress will always be set and Egress will be set if the NetworkPolicy has any egress rules.

This was actually visible:

````buildoutcfg
vagrant@k8sMaster:~
$ cat deny-all.yaml

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}

vagrant@k8sMaster:~
$ k create -f deny-all.yaml
networkpolicy.networking.k8s.io/deny-all created
vagrant@k8sMaster:~
$ k get networkpolicy.networking.k8s.io/deny-all -o yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
[...]
spec:
  podSelector: {}
  policyTypes:
  - Ingress


````

and explains why this is still working:

````buildoutcfg
vagrant@k8sMaster:~
$ k exec -it -c busy newapp -- nc -vz www.mozilla.org 80
www.mozilla.org (104.16.143.228:80) open
````
It was not working in first try because there was an egress rule, and it is additive.
To make it work we could have added an egress whitelist at specific level or global.

#### Using an egress whitelist to show rule additivity

````buildoutcfg
k delete networkpolicies --all

echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec: 
  podSelector: {}
  policyTypes:
  - Ingress 
  - Egress 
#  egress: # at global level, but not much sense, in that case whitelist-all-egress-from-newapp.yaml is not necessary
#  - {}
'> deny-all.yaml

k create -f deny-all.yaml

echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: whitelist-ingress-to-app-from-newapp
spec: 
  podSelector:
    matchLabels:
      svc-name: app
  policyTypes:
  - Ingress 
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          svc-name: newapp
    ports:
    - port: 80
      protocol: TCP
'>  whitelist-ingress-to-app-from-newapp.yaml

k create -f whitelist-ingress-to-app-from-newapp.yaml

echo '
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: whitelist-all-egress-from-newapp
spec: 
  podSelector:
    matchLabels:
      svc-name: newapp
  policyTypes:
  - Ingress 
  - Egress
  egress: 
  - {} # allow all egress for this selector
'> whitelist-all-egress-from-newapp.yaml

k create -f whitelist-all-egress-from-newapp.yaml
````

Interpod is working.
More details on default policy in [doc](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-allow-all-egress-traffic).

Here the specific egress whitelist is added to global egress (which had no whitelist).

Note that if no policyTypes are specified on a NetworkPolicy then by default Ingress will always be set and Egress will be set if the NetworkPolicy has any egress rules.
works also when applied to a specific selector.

## Additional observation with labels

````buildoutcfg
k delete networkpolicies --all
k create -f whitelist.yaml
````

### app - egress 

Rule is applied to the pod with label app, which was the destination (newapp->app)
Thus this is blocked:
````buildoutcfg
k exec -it -c busy app -- nc -vz www.mozilla.org 80
````

If I change the label value of `app`.
````buildoutcfg
kubectl patch pod app -p '{"metadata" : {"labels" : {"svc-name":"app1235"}}}'
```` 

````buildoutcfg
vagrant@k8sMaster:~
$ k get pod app -o yaml | grep -A 1 labels
  labels:
    svc-name: app1235
````

We will see that my restriction rule will not apply

````buildoutcfg
vagrant@k8sMaster:~
$ k exec -it -c busy app -- nc -vz www.mozilla.org 80
www.mozilla.org (104.16.143.228:80) open
````

I revert label value to app, nc is blocked again.
````buildoutcfg
kubectl patch pod app -p '{"metadata" : {"labels" : {"svc-name":"app1235"}}}'
````
For patch see doc [here](https://kubernetes.io/docs/reference/kubectl/cheatsheet/#patching-resources).

### New app ingress permission to app

`interpod-com-test.sh` is working. Now if I change label value of newapp

````buildoutcfg
kubectl patch pod newapp -p '{"metadata" : {"labels" : {"svc-name":"app1234434"}}}'
````
And if doing:
`interpod-com-test.sh`, connexion will be blocked because destination pod  app is protected by policy and newapp does not have the right label value (newapp) to target app.
Reverting the label it is working.
````buildoutcfg
kubectl patch pod newapp -p '{"metadata" : {"labels" : {"svc-name":"newapp"}}}'
````
This OK



#### SEC status

- Finished OK 18apr20
- whitelist seems not working, 
18apr: deny overrides fix .
19apr: apply it to a single pod and understood and explained reason
FULL OK YES OK (voit mail 19apr)
- capabilites eventually come back on this based on work and luska input OPTIONAL => OK DONE
- Partie bis added with new questions
OK DONE
- lien lfd ok
ok
- voir status [Here](0-capabilities-bis-part3-psp-tutorial.md#status) - Nothing to understand
more to contribute

So sec completed