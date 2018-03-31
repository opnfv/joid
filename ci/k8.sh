#!/bin/bash
set -ex

opnfvfeature=$1

juju scp kubernetes-master/0:/home/ubuntu/config ~/joid_config/config

export KUBE_MASTER_IP=`juju status kubernetes-master --format=yaml | grep public-address | cut -d ":" -f 2 | head -1 | sed "s/^[ \t]*//g"`
export KUBE_MASTER_URL=http://${KUBE_MASTER_IP}:6443

configk8(){
cat <<-EOF
export KUBERNETES_PROVIDER=local
export KUBE_MASTER_IP=${KUBE_MASTER_IP}
export KUBE_MASTER_URL=${KUBE_MASTER_URL}
EOF
}

configk8 > ~/joid_config/k8config

juju run-action kubernetes-worker/0 microbot replicas=3
juju config kubernetes-master enable-dashboard-addons=true || true
juju expose kubernetes-worker || true
juju scp -- -r kubernetes kubernetes-master/0:
juju ssh kubernetes-master/0 "/bin/bash kubernetes/post-install.sh $opnfvfeature"
