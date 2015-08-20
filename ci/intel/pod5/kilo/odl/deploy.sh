#!/bin/bash
#placeholder for deployment script.
set -ex

cp intel/pod5/kilo/odl/ovs-odl.yaml ./

echo "... Deployment Started ...."

JUJU_REPOSITORY=
juju set-constraints tags=

juju-deployer -d -r 13 -c ovs-odl.yaml trusty-kilo

echo "... Deployment finished ...."
