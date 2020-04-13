# Network policy

Here.
Start from section 3.2/ 6.5
It is not working as expected probably calico is not working properly... STOP

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

Performing same tests a in section 3.2
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



````


### Egress 

Expect all fail except loopback

````buildoutcfg
k exec -it -c busy app -- nc -vz www.mozilla.org 80 
k exec -it -c busy app -- nc -vz 127.0.0.1 80 
````

Output is:

````buildoutcfg

````

Same 4 tests as 6.5

### Ingress alternative 

Note we could have also:

- used pod ip

````buildoutcfg
export APP_POD_IP=$(k get pods -o wide | grep app | awk '{ print $6 }')
curl $APP_POD_IP | head -n 4
````

Output is

````buildoutcfg

````

- [forward a local port to a port on the pod](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/#forward-a-local-port-to-a-port-on-the-pod)
````buildoutcfg
kubectl port-forward app 7000:80
# In second window but still in VM
curl localhost:7000 | head -n 5
````

Output is

````buildoutcfg


# or from windows if forward the port 7000 in vagrant file (to 7000 or another)
````
