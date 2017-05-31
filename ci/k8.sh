#!/bin/bash
set -ex
juju run-action kubernetes-worker/0 microbot replicas=3
sleep 30
juju config kubernetes-master enable-dashboard-addons=true || true
juju expose kubernetes-worker || true

juju ssh kubernetes-master/0 "/snap/bin/kubectl cluster-info"
juju ssh kubernetes-master/0 "/snap/bin/kubectl get nodes"
juju ssh kubernetes-master/0 "/snap/bin/kubectl get pods --all-namespaces"
juju ssh kubernetes-master/0 "/snap/bin/kubectl get services,endpoints,ingress --all-namespaces"
