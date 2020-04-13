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
