#!/bin/bash
#!/bin/bash
#placeholder for deployment script.
set -ex

case "$1" in
    'nonha' )
        cp opencontrail/juju-deployer/contrail.yaml ./bundles.yaml
        ;;
    'ha' )
        cp opencontrail/juju-deployer/contrail-ha.yaml ./bundles.yaml
        juju-deployer -d -r 13 -c bundles.yaml openstack-phase1
        ;;
    'tip' )
        cp opencontrail/juju-deployer/contrail-tip.yaml ./bundles.yaml
        ;;
    * )
        cp opencontrail/juju-deployer/contrail.yaml ./bundles.yaml
        ;;
esac

echo "... Deployment Started ...."

juju-deployer -d -r 13 -c bundles.yaml trusty-"$2"-contrail

echo "... Deployment finished ...."

