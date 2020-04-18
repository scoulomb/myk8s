set -o xtrace
# Internal DNS (Service ip)
echo -e "\n-- Internal DNS (Service ip)\n"
kubectl exec -it -c busy newapp -- nc -vz app 80
kubectl exec -it -c busy newapp -- wget -O - app | head -n 6

# Service env var (service IP)
echo -e "\n-- Service env var (service IP) \n"
echo 'nc -vz $APP_SERVICE_HOST $APP_SERVICE_PORT' > ~/test.sh
kubectl cp ~/test.sh newapp:/tmp/test.sh -c busy
kubectl exec -it -c busy newapp -- chmod u+x /tmp/test.sh
kubectl exec -it -c busy newapp -- bin/sh /tmp/test.sh

# POD IP directly (see get-pod-ip section in 3.2)
echo -e "\n-- POD IP directly \n"
export APP_POD_IP=$(kubectl get pods -o wide | grep ^app | awk '{ print $6 }')
# Note ^ in grep since  there is now 2 POD called app and newapp
echo $APP_POD_IP
export cmd="nc -vz $APP_POD_IP 80"
kubectl exec -it -c busy newapp -- $cmd

# app to app
echo -e "\n-- app to app \n"
kubectl exec -it -c busy app -- nc -vz app 80

