# Usage: sudo ./deploy-local-registry.yaml

echo 'Clean up'

sudo rm -f /etc/docker/daemon.json
sudo systemctl stop docker.service
sleep 5
sudo systemctl start docker.service

sleep 15
bash ../restart.sh
sleep 20

kubectl delete deployment registry
kubectl delete pvc registry-claim # remove before vol otherwise will bound to new pv
# If volume deletion issue: perform `k edit pv registryvol` remove kubernetes.io/pv-protection and rerun script
kubectl delete pv registryvol

# Create volume
echo 'Volume creation'
echo '
apiVersion: v1
kind: PersistentVolume
metadata:
  labels:
    type: local
  name: registryvol
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 200Mi
  hostPath:
    path: /tmp/registry
  persistentVolumeReclaimPolicy: Retain
' > registryvol.yaml

kubectl delete -f registryvol.yaml
kubectl apply -f registryvol.yaml

# Create registry deployment

echo 'creating registry'

echo '
apiVersion: v1
items:
- apiVersion: v1
  kind: Service
  metadata:
    annotations:
    creationTimestamp: null
    labels:
      service: registry
    name: registry
  spec:
    ports:
    - name: "5000"
      port: 5000
      targetPort: 5000
    selector:
      service: registry
  status:
    loadBalancer: {}
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    labels:
      service: registry
    name: registry
  spec:
    replicas: 1
    selector:
      matchLabels:
        service: registry
    strategy:
      type: Recreate
    template:
      metadata:
        creationTimestamp: null
        labels:
          service: registry
      spec:
        containers:
        - env:
          - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
            value: /data
          image: registry:2
          name: registry
          ports:
          - containerPort: 5000
            hostIP: 127.0.0.1
          resources: {}
          volumeMounts:
          - mountPath: /data
            name: registry-claim
        restartPolicy: Always
        volumes:
        - name: registry-claim
          persistentVolumeClaim:
            claimName: registry-claim
- apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    creationTimestamp: null
    labels:
      service: registry-claim
    name: registry-claim
  spec:
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 100Mi
  status: {}
kind: List
' > localregistry.yaml

kubectl delete -f localregistry.yaml
kubectl apply -f localregistry.yaml

# Update docker daemon
echo 'Update docker daemon'

registry_svc_ip=$(kubectl get svc | grep registry | awk '{ print $3 }')
echo $registry_svc_ip

sudo touch /etc/docker/daemon.json
sudo echo "{ \"insecure-registries\":[\"$registry_svc_ip:5000\"] }" >  /etc/docker/daemon.json
sudo cat /etc/docker/daemon.json

sudo systemctl restart docker.service
sudo systemctl status docker.service | grep Active

# The connection to the server 10.0.2.15:6443 was refused - did you specify the right host or port?
# as we restarted docker, thus run restart
sleep 20
bash ../restart.sh

# If can not start docker this may be due to insecure registry file which is invalid because of IP
# sudo rm -f /etc/docker/daemon.json
# sudo systemctl restart docker.service
# sudo systemctl status docker.service | grep Active
# sudo dockerd --debug for investigation
