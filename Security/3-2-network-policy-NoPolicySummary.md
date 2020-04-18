# Network policy

## Test with no network policy. Summary version

### Create pod and svc

````buildoutcfg

# From `Add a nginx container to test ingress` and adding the selector
echo 'apiVersion: v1
kind: Pod
metadata:
  name: app
  labels:
    svc-name: app
spec:
  containers:
  - name: webserver
    image: nginx
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
' > app.yaml

k delete -f app.yaml
k create -f app.yaml


# From create service, first method
k delete svc app
k expose pod app --type=NodePort --port=80
k edit svc app # Change NodePort to 32000 to target from outside VM
````

### Tests 

### Ingress 

````buildoutcfg
export APP_SVC_IP=$(k get svc | grep app | awk '{ print $3 }')
curl $APP_SVC_IP | head -n 3

# scoulomb@outsideVM
# Here I am using the NodePort (32000), as my VM forwarded port 32000 -> 32000 (guest os -> host os)
# localhost outside VM is equivalent to target Node IP
# curl localhost:32000 # -> OK 
````

Output:

````buildoutcfg
vagrant@k8sMaster:~/toto
$ curl $APP_SVC_IP | head -n 2
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0  55636      0 --:--:-- --:--:-- --:--:-- 55636
<!DOCTYPE html>
<html>

scoulomb@outsideVM:/mnt/c/git_pub/myk8s
$ curl localhost:32000 | head -n 2
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0  76500      0 --:--:-- --:--:-- --:--:-- 76500
<!DOCTYPE html>
<html>
````

### Egress 

````buildoutcfg
k exec -it -c busy app -- nc -vz www.mozilla.org 80 
k exec -it -c busy app -- nc -vz 127.0.0.1 80 
````

Output is:

````buildoutcfg
vagrant@k8sMaster:~/toto # 127.0.0.1 also open
$ k exec -it -c busy app -- nc -vz www.mozilla.org 80
www.mozilla.org (104.16.143.228:80) open
````

### Ingress alternative 

Note we could have also:

- used pod ip

````buildoutcfg
export APP_POD_IP=$(k get pods -o wide | grep app | awk '{ print $6 }')
curl $APP_POD_IP | head -n 4
````

Output is

````buildoutcfg

vagrant@k8sMaster:~/toto
$ curl $APP_POD_IP | head -n 4
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0   597k      0 --:--:-- --:--:-- --:--:--  597k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
````

#### Get pod id 
Note pod can be alternatively found by doing `ip a` (cf 6.5.6)

````buildoutcfg
vagrant@k8sMaster:~
$ k get pods -o wide | grep app
app                                   2/2     Running   13         2d16h   192.168.16.188   k8smaster   <none>           <none>
newapp                                2/2     Running   3          3h26m   192.168.16.132   k8smaster   <none>           <none>

vagrant@k8sMaster:~
$ k exec -it app -c busy -- /bin/sh
/ # ip a | grep -a 5 eth
grep: eth: No such file or directory
/ # ip a | grep -A 5 eth
4: eth0@if21: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1440 qdisc noqueue
    link/ether 76:23:77:15:6e:d6 brd ff:ff:ff:ff:ff:ff
    inet 192.168.16.188/32 scope global eth0  <-- IP is here
       valid_lft forever preferred_lft forever
/ #

````

- [forward a local port to a port on the pod](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/#forward-a-local-port-to-a-port-on-the-pod)
````buildoutcfg
kubectl port-forward app 7000:80
# In second window but still in VM
curl localhost:7000 | head -n 5
````

Output is

````buildoutcfg
vagrant@k8sMaster:~/toto
$ kubectl port-forward app 7000:80
Forwarding from 127.0.0.1:7000 -> 80
Forwarding from [::1]:7000 -> 80

vagrant@k8sMaster:~
$ curl localhost:7000 | head -n 5
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   612  100   612    0     0  16540      0 --:--:-- --:--:-- --:--:-- 16540
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>

# or from windows if forward the port 7000 in vagrant file (to 7000 or another)
````


### Pod to pod communication

It is also interesting to check communication between pods.
`POD NEW APP (egress) -> POD APP  (ingress)`.

I will create a NEW APP pod:

````buildoutcfg
echo 'apiVersion: v1
kind: Pod
metadata:
  name: newapp
  labels:
    svc-name: newapp
spec:
  containers:
  - name: webserver
    image: nginx
  - name: busy
    image: busybox
    command:
     - sleep
     - "3600"
' > newapp.yaml

k delete -f newapp.yaml
k create -f newapp.yaml
````

#### Port 80 - curl

Ant test the communication using `interpod-com-test.sh`

````buildoutcfg
chmod u+x interpod-com-test.sh
./interpod-com-test.sh > out.txt
````

Output is

````buildoutcfg
vagrant@k8sMaster:~
$ cat out.txt

-- Internal DNS (Service ip)

app (10.103.90.128:80) open
Connecting to app (10.103.90.128:80)
writing to stdout
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>

-- Service env var (service IP)

10.103.90.128 (10.103.90.128:80) open

-- POD IP directly

192.168.16.188
192.168.16.188 (192.168.16.188:80) open

-- app to app

app (192.168.16.188:80) open
````

Everything is opened!

#### Ping (Not TCP)

If now we test the ping, we use port 22

````buildoutcfg
chmod u+x interpod-com-test-ping.sh
./interpod-com-test-ping.sh > out.txt
````

Output is

````buildoutcfg
vagrant@k8sMaster:~
$ cat out.txt

-- Internal DNS (Service ip)

PING app (10.103.90.128): 56 data bytes

--- app ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss

-- Service env var (service IP)

PING 10.103.90.128 (10.103.90.128): 56 data bytes

--- 10.103.90.128 ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss

-- POD IP directly

192.168.16.188
PING 192.168.16.188 (192.168.16.188): 56 data bytes
64 bytes from 192.168.16.188: seq=0 ttl=63 time=0.076 ms
64 bytes from 192.168.16.188: seq=1 ttl=63 time=0.123 ms
64 bytes from 192.168.16.188: seq=2 ttl=63 time=0.117 ms

--- 192.168.16.188 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.076/0.105/0.123 ms

-- app to app

PING app (192.168.16.188): 56 data bytes
64 bytes from 192.168.16.188: seq=0 ttl=64 time=0.172 ms
64 bytes from 192.168.16.188: seq=1 ttl=64 time=0.114 ms
64 bytes from 192.168.16.188: seq=2 ttl=64 time=0.062 ms

--- app ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.062/0.116/0.172 ms
````
Even if no policy, ping works with POD IP but not service IP (because a service expose a ip/port here 80)
except when  in `app to app` case because DNS in that case returns pod ip and not service ip.
Here `192.168.16.188`.
