#!/bin/bash
#placeholder for deployment script.
set -ex

cp odl/juju-deployer/ovs-odl.yaml ./

echo "... Deployment Started ...."

#case openstack kilo with odl
juju-deployer -d -r 13 -c ovs-odl.yaml trusty-kilo

#case openstack kilo with odl ha
#juju-deployer -d -r 13 -c ovs-odl-ha.yaml trusty-kilo

#case openstack master tip git tree with odl
#cp -R odl/juju-deployer/source/*.yaml ./
#juju-deployer -d -r 13 -c ovs-odl-tip.yaml trusty-master-kilo

echo "... Deployment finished ...."
