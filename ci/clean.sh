#!/bin/bash

set -ex

if [ ! -d environments.yaml ]; then
    cp ~/joid_config/environments.yaml ./environments.yaml
fi

jujuver=`juju --version`

if [ "$jujuver" -ge "2" ]; then
    controllername=`awk 'NR==1{print $2}' environments.yaml`
    cloudname=`awk 'NR==1{print $2}' environments.yaml`
    juju kill-controller $controllername --timeout 10s -y || true
    rm -rf precise
    rm -rf trusty
    rm -rf xenial
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
fi

