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

case "$3" in
    'orangepod2' )
        sed -i -- 's/10.4.1.1/192.168.2.2/g' ./bundles.yaml
        ;;
    'intelpod6' )
        sed -i -- 's/10.4.1.1/10.4.1.2/g' ./bundles.yaml
        ;;
    'intelpod5' )
        sed -i -- 's/10.4.1.1/10.4.1.2/g' ./bundles.yaml
        ;;
esac

echo "... Deployment Started ...."
case "$1" in
    'nonha' )
        juju-deployer -vW -d -c bundles.yaml trusty-"$2"
        ;;
    'ha' )
        juju-deployer -vW -d -c bundles.yaml openstack-phase1
        juju-deployer -vW -d -c bundles.yaml trusty-"$2"-nodes
        juju-deployer -vW -d -c bundles.yaml openstack-phase3
        juju-deployer -vW -d -c bundles.yaml trusty-"$2"
        ;;
    'tip' )
        juju-deployer -vW -d -c bundles.yaml trusty-"$2"
        ;;
    * )
        juju-deployer -vW -d -c bundles.yaml trusty-"$2"
        ;;
esac
echo "... Deployment finished ...."
