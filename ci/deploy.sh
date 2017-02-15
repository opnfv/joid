#!/bin/bash

set -ex

#need to put mutiple cases here where decide this bundle to deploy by default use the odl bundle.
# Below parameters are the default and we can according the release

opnfvsdn=nosdn
opnfvtype=nonha
openstack=newton
opnfvlab=default
opnfvrel=d
opnfvfeature=none
opnfvdistro=xenial
opnfvarch=amd64
opnfvmodel=openstack

jujuver=`juju --version`

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
                         [-f <ipv6,dpdk,lxd,dvr>]
                         [-d <trusty|xenial>]
                         [-a <amd64>]
                         [-m <openstack|kubernetes>]
                         [-r <a|b>]" 1>&2 exit 1; }

while getopts ":s:t:o:l:h:r:f:d:a:m:" opt; do
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
        f)
            opnfvfeature=${OPTARG}
            ;;
        d)
            opnfvdistro=${OPTARG}
            ;;
        a)
            opnfvarch=${OPTARG}
            ;;
        m)
            opnfvmodel=${OPTARG}
            ;;
        h)
            usage
            ;;
        *)
            ;;
    esac
done

#by default maas creates two VMs in case of three more VM needed.
createresource() {
    # TODO: make sure this function run with the same parameters used in 03-maasdeploy.sh
    PROFILE=${PROFILE:-ubuntu}
    MAAS_IP=$(grep " ip_address" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //')
    API_SERVER="http://$MAAS_IP/MAAS/api/2.0"
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVER $API_KEY

    for node in node3-control node4-control
    do
        node_id=$(maas $PROFILE machines read | \
                  jq -r "select(.[].hostname == \"$node\")[0].system_id")
        if [[ -z "$node_id" ]]; then
            sudo virt-install --connect qemu:///system --name $node \
                --ram 8192 --cpu host --vcpus 4 \
                --disk size=120,format=qcow2,bus=virtio,io=native,pool=default \
                --network bridge=virbr0,model=virtio \
                --network bridge=virbr0,model=virtio \
                --boot network,hd,menu=off \
                --noautoconsole --vnc --print-xml | tee _node.xml
            node_mac=$(grep "mac address" _node.xml | head -1 | cut -d "'" -f 2)
            sudo virsh -c qemu:///system define --file _node.xml
            rm -f _node.xml

            maas $PROFILE nodes new autodetect_nodegroup='yes' name=$node \
                tags='control' hostname=$name power_type='virsh' \
                mac_addresses=$node3controlmac \
                power_parameters_power_address="qemu+ssh://$USER@192.168.122.1/system" \
                architecture='amd64/generic' power_parameters_power_id='node3-control'
            node_id=$(maas $PROFILE machines read | \
                  jq -r "select(.[].hostname == \"$node\")[0].system_id")
        fi
        if [[ -z "$node_id" ]]; then
            echo "Error: failed to create node $node ."
            exit 1
        fi
        maas $PROFILE tag update-nodes control add=$node_id || true
    done
}

#copy the files and create extra resources needed for HA deployment
# in case of default VM labs.
deploy() {
    if [[ "$jujuver" > "2" ]]; then
        if [ ! -f ./labconfig.yaml ] && [ -e ~/joid_config/labconfig.yaml ]; then
            cp ~/joid_config/labconfig.yaml ./labconfig.yaml

            if [ ! -f ./deployconfig.yaml ] && [ -e ~/joid_config/deployconfig.yaml ]; then
                cp ~/joid_config/deployconfig.yaml ./deployconfig.yaml
            else
                python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
            fi
        else
            if [ -e ./labconfig.yaml ]; then
                if [ ! -f ./deployconfig.yaml ] && [ -e ~/joid_config/deployconfig.yaml ]; then
                    cp ~/joid_config/deployconfig.yaml ./deployconfig.yaml
                else
                    python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
                fi
            else
                echo " MAAS not deployed please deploy MAAS first."
            fi
        fi
    else
        if [ ! -f ./environments.yaml ] && [ -e ~/.juju/environments.yaml ]; then
            cp ~/.juju/environments.yaml ./environments.yaml
        elif [ ! -f ./environments.yaml ] && [ -e ~/joid_config/environments.yaml ]; then
            cp ~/joid_config/environments.yaml ./environments.yaml
        fi
        #copy the script which needs to get deployed as part of ofnfv release
        echo "...... deploying now ......"
        echo "   " >> environments.yaml
        echo "        enable-os-refresh-update: false" >> environments.yaml
        echo "        enable-os-upgrade: false" >> environments.yaml
        echo "        admin-secret: admin" >> environments.yaml
        echo "        default-series: $opnfvdistro" >> environments.yaml
        cp environments.yaml ~/.juju/
        cp environments.yaml ~/joid_config/
    fi

    if [[ "$opnfvtype" = "ha" && "$opnfvlab" = "default" ]]; then
        createresource
    fi

    #bootstrap the node
    ./01-bootstrap.sh

    if [[ "$jujuver" > "2" ]]; then
        juju model-config default-series=$opnfvdistro enable-os-refresh-update=false enable-os-upgrade=false
    fi

    #case default deploy the opnfv platform:
    ./02-deploybundle.sh $opnfvtype $openstack $opnfvlab $opnfvsdn $opnfvfeature $opnfvdistro $opnfvmodel
}

#check whether charms are still executing the code even juju-deployer says installed.
check_status() {
    retval=0
    timeoutiter=0

    echo -n "executing the reltionship within charms ."
    while [ $retval -eq 0 ]; do
       sleep 30
       if juju status | grep -q "executing"; then
           echo -n '.'
           if [ $timeoutiter -ge 120 ]; then
               echo 'timed out'
               retval=1
           fi
           timeoutiter=$((timeoutiter+1))
       else
           echo 'done'
           retval=1
       fi
    done

    if [[ "$opnfvmodel" = "openstack" ]]; then
        juju expose ceph-radosgw || true
        #juju ssh ceph/0 \ 'sudo radosgw-admin user create --uid="ubuntu" --display-name="Ubuntu Ceph"'
    fi
    echo "...... deployment finishing ......."
}

echo "...... deployment started ......"
deploy

check_status

echo "...... deployment finished  ......."

if [[ "$opnfvmodel" = "openstack" ]]; then
    ./openstack.sh "$opnfvsdn" "$opnfvlab" "$opnfvdistro" "$openstack" || true

    # creating heat domain after puching the public API into /etc/hosts

    if [[ "$jujuver" > "2" ]]; then
        status=`juju run-action heat/0 domain-setup`
        echo $status
    else
        status=`juju action do heat/0 domain-setup`
        echo $status
    fi


    sudo ../juju/get-cloud-images || true
    ../juju/joid-configure-openstack || true

fi
if [[ "$opnfvmodel" = "kubernetes" ]]; then
    ./k8.sh
fi

echo "...... finished  ......."
