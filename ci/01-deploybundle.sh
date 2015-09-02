#!/bin/bash
#placeholder for deployment script.
set -ex

case "$1" in
    'nonha' )
        cp odl/juju-deployer/ovs-odl.yaml ./bundles.yaml
        ;;
    'ha' )
        cp odl/juju-deployer/ovs-odl-ha.yaml ./bundles.yaml
        ;;
    'tip' )
        cp odl/juju-deployer/ovs-odl-tip.yaml ./bundles.yaml
        ;;
    * )
        cp odl/juju-deployer/ovs-odl.yaml ./bundles.yaml
        ;;
esac

echo "... Deployment Started ...."

#case openstack kilo with odl
juju-deployer -d -r 13 -c bundles.yaml trusty-"$2"

echo "... Deployment finished ...."
