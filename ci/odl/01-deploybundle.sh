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
        sed -i -- 's/#os-data-network/os-data-network/g' ./bundles.yaml
        ;;
    'intelpod5' )
        sed -i -- 's/10.4.1.1/10.4.1.2/g' ./bundles.yaml
        sed -i -- 's/#os-data-network/os-data-network/g' ./bundles.yaml
        ;;
esac

echo "... Deployment Started ...."
case "$1" in
    'ha' )
        juju-deployer -vW -d -c bundles.yaml trusty-"$2"-nodes
        case "$3" in
            'orangepod2' )
                juju run --service nodes-api 'sudo ifup eth3'
                juju run --service nodes-compute 'sudo ifup eth5'
            ;;
            'intelpod6' )
                juju run --service nodes-api 'sudo ifup eth1'
                juju run --service nodes-compute 'sudo ifup eth1'
            ;;
            'intelpod5' )
                juju run --service nodes-api 'sudo ifup eth1'
                juju run --service nodes-compute 'sudo ifup eth1'
            ;;
        esac
        ;;
esac

juju-deployer -vW -d -c bundles.yaml trusty-"$2"

echo "... Deployment finished ...."
