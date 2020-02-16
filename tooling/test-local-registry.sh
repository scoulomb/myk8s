## TEST

cd ~
mkdir apptest
cd apptest

echo '
#!/usr/bin/python
## Import the necessary modules
import time
import socket

## Use an ongoing while loop to generate output
while True :
  host = socket.gethostname()
  date = time.strftime("%Y-%m-%d %H:%M:%S")
  print(f"> host: {host}\n> date: {date}\n")
  time.sleep(5)
' > testregistry.py

echo '
FROM python:3
ADD testregistry.py /
# https://stackoverflow.com/questions/29663459/python-app-does-not-print-anything-when-running-detached-in-docker
CMD ["python", "-u", "./testregistry.py"]
' > Dockerfile

sudo docker build -t testregistry .
registry_svc_ip=$(kubectl get svc | grep registry | awk '{ print $3 }')
echo $registry_svc_ip
sudo docker tag testregistry $registry_svc_ip:5000/testregistry
sudo docker push $registry_svc_ip:5000/testregistry
# sudo docker run $registry_svc_ip:5000/testregistry

k delete deployment test-registry
k create deployment test-registry --image $registry_svc_ip:5000/testregistry -o yaml

sleep 30
export POD_NAME_1=$(k get pods -o wide | grep "test-registry-" |  sed -n 1p | awk '{ print $1 }')
echo $POD_NAME_1
k logs -f $POD_NAME_1
# We see it outputs logs!