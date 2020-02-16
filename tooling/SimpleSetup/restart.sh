sudo swapoff -a
sudo kubeadm init --kubernetes-version 1.16.1 --pod-network-cidr 192.168.0.0/16

sleep 15

kubectl apply -f rbac-kdd.yaml
kubectl apply -f calico.yaml

sleep 2

kubectl get node

echo "restart finished!"



