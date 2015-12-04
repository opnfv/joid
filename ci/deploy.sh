#!/bin/bash

set -ex

#need to put mutiple cases here where decide this bundle to deploy by default use the odl bundle.
# Below parameters are the default and we can according the release

opnfvsdn=nosdn
opnfvtype=nonha
openstack=liberty
opnfvlab=default
opnfvrel=b

read_config() {
    opnfvrel=`grep release: deploy.yaml | cut -d ":" -f2`
    openstack=`grep openstack: deploy.yaml | cut -d ":" -f2`
    opnfvtype=`grep type: deploy.yaml | cut -d ":" -f2`
    opnfvlab=`grep lab: deploy.yaml | cut -d ":" -f2`
    opnfvsdn=`grep sdn: deploy.yaml | cut -d ":" -f2`
}

usage() { echo "Usage: $0 [-s <nosdn|odl|opencontrail>]
                         [-t <nonha|ha|tip>] 
                         [-o <juno|liberty>]
                         [-l <default|intelpod5>]
                         [-r <a|b>]" 1>&2 exit 1; } 

while getopts ":s:t:o:l:h:r:" opt; do
    case "${opt}" in
        s)
            opnfvsdn=${OPTARG}
            ;;
        t)
            opnfvtype=${OPTARG}
            ;;
        o)
            openstack=${OPTARG}
            ;;
        l)
            opnfvlab=${OPTARG}
            ;;
        r)
            opnfvrel=${OPTARG}
            ;;
        h)
            usage
            ;;
        *)
            ;;
    esac
done

deploy_dep() {
    sudo apt-add-repository ppa:juju/stable -y
    sudo apt-get update
    sudo apt-get install juju git juju-deployer -y
    juju init -f
    cp environments.yaml ~/.juju/
}

deploy() {
    #copy the script which needs to get deployed as part of ofnfv release
    echo "...... deploying now ......"
    echo "   " >> environments.yaml
    echo "        enable-os-refresh-update: false" >> environments.yaml
    echo "        enable-os-upgrade: false" >> environments.yaml
    echo "        admin-secret: admin" >> environments.yaml
    echo "        default-series: trusty" >> environments.yaml

    cp environments.yaml ~/.juju/

    cp ./$opnfvsdn/01-deploybundle.sh ./01-deploybundle.sh
    ./00-bootstrap.sh

    #case default:
    ./01-deploybundle.sh $opnfvtype $openstack $opnfvlab
}

check_status() {
    while [ $? -eq 0 ]; do
       sleep 60
       echo " still executing the reltionship within charms ..."
       juju status | grep executing > /dev/null
    done
    echo "...... deployment finishing ......."
}

if [ "$#" -eq 0 ]; then
  echo "This installtion will use deploy.yaml" 
  read_config
fi

echo "...... deployment started ......"
#deploy_dep
deploy
check_status

echo "...... deployment finished  ......."

