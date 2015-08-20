#!/bin/bash
#placeholder for deployment script.
set -ex

cp intel/pod5/kilo/master/odl/ha/ovs-odl-tip.yaml ./
cp intel/pod5/kilo/master/odl/source/*.yaml ./

echo "Deployment Started ...."

JUJU_REPOSITORY=
juju set-constraints tags=
juju-deployer -d -r 13 -c ovs-odl-tip.yaml trusty-master-kilo

echo "... Deployment finished"
