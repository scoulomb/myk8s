#!/bin/bash


# Sanity Tests
kubectl get node
kubectl describe nodes | grep -i Taint

# Removing taints to allow pod scheduling on master (our single node)
kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl describe nodes | grep -i taint
# When scheduling a pod before taint it will failed when removing taint it will be scheduled