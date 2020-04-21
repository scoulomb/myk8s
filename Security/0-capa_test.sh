#!/bin/bash

capa_test () {
  set -x
  kubectl exec $1 -- id || true
  kubectl exec $1 -- grep Cap /proc/1/status | grep CapBnd || true
  kubectl exec $1 -- traceroute 127.0.0.1
  kubectl exec $1 -- date +%T -s "12:00:00" || true
  kubectl exec $1 -- chmod 777 home ; echo $? || true
  kubectl exec $1 -- chown nobody / ; echo $? || true
}

