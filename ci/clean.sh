#!/bin/bash

set -ex

jujuver=`juju --version`

if [[ "$jujuver" > "2" ]]; then
    if [ ! -d labconfig.yaml ]; then
        cp ~/joid_config/labconfig.yaml ./labconfig.yaml || true
        if [ -d $HOME/joid_config/deployconfig.yaml ]; then
            cp ~/joid_config/deployconfig.yaml ./deployconfig.yaml || true
        else
            python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
        fi
    fi
else
    if [ ! -d environments.yaml ]; then
        cp ~/joid_config/environments.yaml ./environments.yaml || true
        cp ~/.juju/environments.yaml ./environments.yaml || true
    fi
fi


if [[ "$jujuver" > "2" ]]; then
    controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`
    cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`
    juju kill-controller $controllername --timeout 10s -y || true
    rm -rf precise
    rm -rf trusty
    rm -rf xenial
    rm -rf ~/joid_config/admin-openrc
    sleep 30
    sudo sysctl -w vm.drop_caches=3
elif [ -d $HOME/.juju/environments ]; then
    echo " " > status.txt
    juju status  &>>status.txt || true
    if [ "$(grep -c "environment is not bootstrapped" status.txt )" -ge 1 ]; then
        echo " environment is not bootstrapped ..."
    else
        echo " environment is bootstrapped ..."
        jujuenv=`juju status | grep environment | cut -d ":" -f 2`
        juju destroy-environment $jujuenv  -y || true
    fi
    rm -rf precise
    rm -rf trusty
    rm -rf xenial
    rm -rf $HOME/.juju/j*
    rm -rf $HOME/.juju/.deployer-store-cache
    rm -rf $HOME/.juju/environments
    rm -rf $HOME/.juju/ssh
    sudo sysctl -w vm.drop_caches=3
fi
