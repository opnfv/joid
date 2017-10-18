#!/bin/bash
set -ex

opnfvfeature=$1

juju run-action kubernetes-worker/0 microbot replicas=3
juju config kubernetes-master enable-dashboard-addons=true || true
juju expose kubernetes-worker || true
juju scp -- -r kubernetes kubernetes-master/0:
juju ssh kubernetes-master/0 "/bin/bash kubernetes/post-install.sh $opnfvfeature"
