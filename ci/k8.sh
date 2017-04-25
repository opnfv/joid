#!/bin/bash
set -ex
juju run-action kubernetes-worker/0 microbot replicas=3
sleep 30
mkdir -p ~/.kube || true
juju scp kubernetes-master/0:config ~/.kube/config || true

if [ ! -f /snap/kubectl/current/kubectl ]; then
  sudo snap install kubectl --classic
fi

if [ ! -f ./kubectl ]; then
  ln -s /snap/kubectl/current/kubectl ./kubectl
fi

./kubectl cluster-info || true
juju config kubernetes-master enable-dashboard-addons=true || true
#./kubectl proxy
#http://localhost:8001/ui
./kubectl get nodes || true
#./kubectl create -f example.yaml || true
./kubectl get pods --all-namespaces || true
./kubectl get services,endpoints,ingress --all-namespaces || true
juju expose kubernetes-worker || true
