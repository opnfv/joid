#!/bin/bash

set -ex

if [ ! -d environments.yaml ]; then
    cp ~/joid_config/environments.yaml ./environments.yaml || true
    cp ~/.juju/environments.yaml ./environments.yaml || true
fi

if [ ! -d deployment.yaml ]; then
    cp ~/joid_config/deployment.yaml ./deployment.yaml || true
    cp ~/.juju/deployment.yaml ./deployment.yaml || true
fi

jujuver=`juju --version`

if [[ "$jujuver" > "2" ]]; then
    controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployment.yaml`
    cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployment.yaml`
    juju kill-controller $controllername --timeout 10s -y || true
    rm -rf precise
    rm -rf trusty
    rm -rf xenial
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

#sudo apt-get purge maas maas-cli maas-common maas-dhcp maas-dns maas-proxy maas-rack-controller maas-region-api maas-region-controller  -y
#sudo rm -rf /var/lib/maas
