#!/bin/bash

set -ex
./00-bootstrap.sh

#need to put mutiple cases here where decide this bundle to deploy by default use the odl bundle.
# Below parameters are the default and we can according the release

opnfvsdn=odl
opnfvtype=nonha
openstack=kilo
opnfvlab=intelpod5

usage() { echo "Usage: $0 [-s <odl|opencontrail>]
                         [-t <nonha|ha|tip>] 
                         [-o <juno|kilo|liberty>]
                         [-l <intelpod5>]" 1>&2 exit 1;}

while getopts ":s:t:o:l:h:" opt; do
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
        h)
            usage
            ;;
        *)
            ;;
    esac
done

#copy the script which needs to get deployed as part of ofnfv release
cp ./$opnfvsdn/01-deploybundle.sh ./01-deploybundle.sh

#case default:
./01-deploybundle.sh $opnfvtype $openstack $opnfvlab

