#!/bin/bash

set -ex

if [ ! -d labconfig.yaml ]; then
    cp ~/joid_config/labconfig.yaml ./labconfig.yaml || true
    if [ -d $HOME/joid_config/deployconfig.yaml ]; then
        cp ~/joid_config/deployconfig.yaml ./deployconfig.yaml || true
    else
        python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
    fi
fi

controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`
cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`
juju destroy-controller $controllername --destroy-all-models -y || true
#juju kill-controller $controllername --timeout 10s -y || true
rm -rf precise
rm -rf trusty
rm -rf xenial
rm -rf ~/joid_config/admin-openrc
sleep 10
sudo sysctl -w vm.drop_caches=3
