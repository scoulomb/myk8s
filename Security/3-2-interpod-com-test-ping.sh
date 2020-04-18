set -o xtrace
# Internal DNS (Service ip)
echo -e "\n-- Internal DNS (Service ip)\n"
kubectl exec -it -c busy newapp -- ping -c 5 app

# Service env var (service IP)
echo -e "\n-- Service env var (service IP) \n"
echo 'ping -c 5 $APP_SERVICE_HOST' > ~/testping.sh
kubectl cp ~/testping.sh newapp:/tmp/testping.sh -c busy
kubectl exec -it -c busy newapp -- chmod u+x /tmp/testping.sh
kubectl exec -it -c busy newapp -- bin/sh /tmp/testping.sh

# POD IP directly (see get-pod-ip section in 3.2)
echo -e "\n-- POD IP directly \n"
export APP_POD_IP=$(kubectl get pods -o wide | grep ^app | awk '{ print $6 }')
# Note ^ in grep since  there is now 2 POD called app and newapp
echo $APP_POD_IP
export cmd="ping -c 3 $APP_POD_IP"
kubectl exec -it -c busy newapp -- $cmd

# app to app
echo -e "\n-- app to app \n"
kubectl exec -it -c busy app -- ping -c 3 app

