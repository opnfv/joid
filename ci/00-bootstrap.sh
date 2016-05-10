#!/bin/bash

set -ex

#export JUJU_DEV_FEATURE_FLAGS=address-allocation

juju bootstrap --debug --to bootstrap.maas
sleep 5
#disable juju gui until xenial charms are in charm store.
#juju deploy juju-gui --to 0

JUJU_REPOSITORY=
juju set-constraints tags=

