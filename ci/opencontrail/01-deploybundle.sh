#!/bin/bash
#placeholder for deployment script.
set -ex

cp opencontrail/juju-deployer/contrail.yaml ./

echo "... Deployment Started ...."

#case openstack kilo with odl
juju-deployer -d -r 13 -c contrail.yaml trusty-juno-contrail

#case openstack kilo with odl ha
#juju-deployer -d -r 13 -c contrail-ha.yaml trusty-juno-contrail

#case openstack master tip git tree with odl
#cp -R odl/juju-deployer/source/*.yaml ./
#juju-deployer -d -r 13 -c contrail-tip.yaml trusty-juno-contrail

echo "... Deployment finished ...."
