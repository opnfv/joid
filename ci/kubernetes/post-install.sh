#!/bin/bash
set -ex

if [[ $1 == *"multus"* ]]; then
    /snap/bin/kubectl apply -f kubernetes/kube_cni_multus.yml
fi

/snap/bin/kubectl apply -f kubernetes/nginx-app.yaml
/snap/bin/kubectl cluster-info
/snap/bin/kubectl get nodes
/snap/bin/kubectl get pods --all-namespaces
/snap/bin/kubectl get services,endpoints,ingress --all-namespaces
