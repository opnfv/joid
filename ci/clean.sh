#!/bin/bash

set -ex

if [ -d "~/.juju/environemnts" ]; then
    juju status  &>status.txt || true
    if [ "$(grep -c "environment is not bootstrapped" status.txt )" -ge 1 ]; then
        echo " environment is not bootstrapped ..."
    else
        echo " environment is bootstrapped ..."
        juju destroy-environment demo-maas  -y
        rm -rf ~/.juju/j*
        rm -rf ~/.juju/.deployer-store-cache
    fi
    rm -rf ~/.juju/environments
    rm -rf ~/.juju/ssh
fi

