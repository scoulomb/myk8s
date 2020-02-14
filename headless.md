k delete svc,deployment --all
k create deployment deploy1 --image=nginx
k scale --replicas=3 deployment/deploy1
k expose deployment deploy1 --port=80 --type=ClusterIP 
k get svc

k create deployment deploy2 --image=nginx

k exec -it deploy2-5ff54b6b7b-r247s -- /bin/bash
# apt-get update 
# apt-get install curl
# apt-get install dnsutils
# could do my img
curl deploy1
dig deploy1

k edit svc deploy1
set cluster ip to None (partial modify?)
dig
curl

-------
puis endpoint, reusing resource [in](service_deep_dive.md#Service-without-a-selector)
k apply -f svc-no-sel.yaml 
k apply -f ep-no-sel.yaml

puis puis [external name](service_deep_dive.md#ExternalName)

all headless need to use ip
