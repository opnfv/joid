#!/bin/bash

set -ex

#export JUJU_DEV_FEATURE_FLAGS=address-allocation

jujuver=`juju --version`

if [[ "$jujuver" < "2" ]]; then
  juju bootstrap --debug --to bootstrap.maas
  sleep 5
  #disable juju gui until xenial charms are in charm store.
  juju deploy cs:juju-gui-130 --to 0

  JUJU_REPOSITORY=
  juju set-constraints tags=

else
  controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployment.yaml`
  cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployment.yaml`
  juju bootstrap $controllername $cloudname --debug --to bootstrap.maas
fi
