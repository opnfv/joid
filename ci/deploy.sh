#!/bin/bash
<<<<<<< HEAD
#placeholder for deployment script.
set -ex

cp intel/pod5/kilo/odl/nonha/deploy.sh ./deployopnfv.sh

echo "bootstrap started"
juju bootstrap --debug --to bootstrap.maas
sleep 15
juju deploy juju-gui --to 0

echo "bootstrap finished"

./deployopnfv.sh

=======

set -ex
./01-bootstrap.sh

#need to put mutiple cases here where decide this bundle to deploy by default use the odl bundle.

#case deploy opencontrail 
#cp ./opencontrail/01-deploybundle.sh ./01-deploybundle.sh

#case deploy ODL bundle
cp ./odl/01-deploybundle.sh ./01-deploybundle.sh

#case default:
./01-deploybundle.sh

#case ha:
#./01-deploybundle.sh ha

#case tip
#./01-deploybundle.sh tip
>>>>>>> 3b30953... Added a script to have a openstack with odl bundle.
