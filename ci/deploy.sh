#!/bin/bash

set -ex

#need to put mutiple cases here where decide this bundle to deploy by default use the odl bundle.
# Below parameters are the default and we can according the release

opnfvsdn=odl
opnfvtype=nonha
openstack=kilo
opnfvlab=intelpod5
opnfvrel=b

read_config() {
    opnfvrel=`grep release: deploy.yaml | cut -d ":" -f2`
    openstack=`grep openstack: deploy.yaml | cut -d ":" -f2`
    opnfvtype=`grep type: deploy.yaml | cut -d ":" -f2`
    opnfvlab=`grep lab: deploy.yaml | cut -d ":" -f2`
    opnfvsdn=`grep sdn: deploy.yaml | cut -d ":" -f2`
}

usage() { echo "Usage: $0 [-s <odl|opencontrail>]
                         [-t <nonha|ha|tip>] 
                         [-o <juno|kilo|liberty>]
                         [-l <intelpod5>]
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

deploy() {
    #copy the script which needs to get deployed as part of ofnfv release
    echo "deploying now"
    cp ./$opnfvsdn/01-deploybundle.sh ./01-deploybundle.sh
    ./00-bootstrap.sh

    #case default:
    ./01-deploybundle.sh $opnfvtype $openstack $opnfvlab
}

if [ "$#" -eq 0 ]; then
  echo "This installtion will use deploy.yaml" 
  read_config
fi

echo "deploying started"
deploy
echo "deploying finished"
