# Network policy

## Deny all

## Create

https://kubernetes.io/docs/concepts/services-networking/network-policies/

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
  - Egress
'> deny-all.yaml

k create -f deny-all.yaml
````


## Tests 

Performing same tests a in [3.2 summary](./3-2-network-policy-NoPolicySummary.md).

### Ingress 

Expect all fail

````buildoutcfg
export APP_SVC_IP=$(k get svc | grep app | awk '{ print $3 }')
curl $APP_SVC_IP | head -n 3

# scoulomb@outsideVM
# Here I am using the NodePort (32000), as my VM forwarded port 32000 -> 32000 (guest os -> host os)
# localhost outside VM is equivalent to target Node IP
# curl localhost:32000 
````

Output:

````buildoutcfg
vagrant@k8sMaster:~
$ curl $APP_SVC_IP | head -n 3
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   199k      0 --:--:-- --:--:-- --:--:--  199k
<!DOCTYPE html>
<html>
<head>


scoulomb@outsideVM:/mnt/c/Users/scoulombel
$ curl localhost:32000
curl: (52) Empty reply from server

````

In this setup from the node I still have access inside node (different from some training material) but not from outside.

(Equivalent to:
- 6.5.3 (note port 80 optional) -> 5.15b
- 6.5.2 (not error in port in training) ) -> 5.15a

### Egress 

Expect all fail except loopback

````buildoutcfg
k exec -it -c busy app -- nc -vz www.mozilla.org 80 
k exec -it -c busy app -- nc -vz 127.0.0.1 80 
````

Output is:

````buildoutcfg
vagrant@k8sMaster:~
$ k exec -it -c busy app -- nc -vz www.mozilla.org 80
nc: bad address 'www.mozilla.org'
command terminated with exit code 1
vagrant@k8sMaster:~
$ k exec -it -c busy app -- nc -vz 127.0.0.1 80
127.0.0.1 (127.0.0.1:80) open
vagrant@k8sMaster:~

````

Here egress is working only on loopback but not to the outside.


### Ingress alternative 

Note we could have also:

- used pod ip

````buildoutcfg
export APP_POD_IP=$(k get pods -o wide | grep ^app | awk '{ print $6 }')
# added ^ as newapp now exists
curl $APP_POD_IP | head -n 4
````

Output is

````buildoutcfg
vagrant@k8sMaster:~
$ curl $APP_POD_IP | head -n 4
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--
100   612  100   612    0     0   597k      0 --:--:-- --:--:-- --:--:--  597k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
100   612  100   612    0     0   597k      0 --:--:-- --:--:-- --:--:--  597k
(23) Failed writing body
````

- [forward a local port to a port on the pod](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/#forward-a-local-port-to-a-port-on-the-pod)
````buildoutcfg
kubectl port-forward app 7000:80
# In second window but still in VM
curl localhost:7000 | head -n 5
````

Output is

````buildoutcfg
vagrant@k8sMaster:~
$ kubectl port-forward app 7000:80
Forwarding from 127.0.0.1:7000 -> 80
Forwarding from [::1]:7000 -> 80

vagrant@k8sMaster:~                                                                          
$  curl localhost:7000 | head -n 5                                                           
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current              
                                 Dload  Upload   Total   Spent    Left  Speed                
100   612  100   612    0     0  15300      0 --:--:-- --:--:-- --:--:-- 15692               
<!DOCTYPE html>                                                                              
<html>                                                                                       
<head>                                                                                       
<title>Welcome to nginx!</title>                                                             
<style>                                                                                      

# or from windows if forward the port 7000 in vagrant file (to 7000 or another)
# -> not tested if difference here
````

No behavior change was seen here when policy is there.



### Pod to pod communication


`POD NEW APP (egress) -> POD APP  (ingress)`.

Ant test the communication


#### Port 80 - curl

Ant test the communication using `interpod-com-test.sh`

````buildoutcfg
chmod u+x interpod-com-test.sh
./interpod-com-test.sh 
````

Output is

````buildoutcfg
vagrant@k8sMaster:~
$ ./interpod-com-test.sh
++ echo -e '\n-- Internal DNS (Service ip)\n'

-- Internal DNS (Service ip)

++ kubectl exec -it -c busy newapp -- nc -vz app 80
nc: bad address 'app'
command terminated with exit code 1
++ kubectl exec -it -c busy newapp -- wget -O - app
++ head -n 6
wget: bad address 'app'
command terminated with exit code 1
++ echo -e '\n-- Service env var (service IP) \n'

-- Service env var (service IP)

++ echo 'nc -vz $APP_SERVICE_HOST $APP_SERVICE_PORT'
++ kubectl cp /home/vagrant/test.sh newapp:/tmp/test.sh -c busy
++ kubectl exec -it -c busy newapp -- chmod u+x /tmp/test.sh
++ kubectl exec -it -c busy newapp -- bin/sh /tmp/test.sh
nc: 10.103.90.128 (10.103.90.128:80): Connection timed out
command terminated with exit code 1
++ echo -e '\n-- POD IP directly \n'

-- POD IP directly

+++ awk '{ print $6 }'
+++ kubectl get pods -o wide
+++ grep '^app'
++ export APP_POD_IP=192.168.16.188
++ APP_POD_IP=192.168.16.188
++ echo 192.168.16.188
192.168.16.188
++ export 'cmd=nc -vz 192.168.16.188 80'
++ cmd='nc -vz 192.168.16.188 80'
++ kubectl exec -it -c busy newapp -- nc -vz 192.168.16.188 80
nc: 192.168.16.188 (192.168.16.188:80): Connection timed out
command terminated with exit code 1
++ echo -e '\n-- app to app \n'

-- app to app

++ kubectl exec -it -c busy app -- nc -vz app 80
app (192.168.16.188:80) open
````

Everything is close! except pod to same pod.

#### Ping (not TCP)

If now we test the ping, we use port 22

````buildoutcfg
chmod u+x interpod-com-test-ping.sh
./interpod-com-test-ping.sh 
````

Output is

````buildoutcfg
vagrant@k8sMaster:~
$ ./interpod-com-test-ping.sh
++ echo -e '\n-- Internal DNS (Service ip)\n'

-- Internal DNS (Service ip)

++ kubectl exec -it -c busy newapp -- ping -c 5 app
ping: bad address 'app'
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
64 bytes from 192.168.16.188: seq=0 ttl=64 time=0.032 ms
64 bytes from 192.168.16.188: seq=1 ttl=64 time=0.045 ms
64 bytes from 192.168.16.188: seq=2 ttl=64 time=0.076 ms

--- app ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.032/0.051/0.076 ms
````

Here with policy when using POD IP it is not working anymore. 
Only pod to same pod is working.

[Next](./3-4-network-policy-RelaxingPolicy.md)