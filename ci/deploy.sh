#!/bin/bash
#placeholder for deployment script.
set -ex

cp intel/pod5/kilo/odl/nonha/deploy.sh ./deployopnfv.sh

echo "bootstrap started"
juju bootstrap --debug --to bootstrap.maas
sleep 15
juju deploy juju-gui --to 0

echo "bootstrap finished"

./deployopnfv.sh

