#!/bin/bash

set -ex

source common/tools.sh

#need to put multiple cases here where decide this bundle to deploy by default use the odl bundle.
# Below parameters are the default and we can according the release

opnfvsdn=nosdn
opnfvtype=noha
openstack=queens
opnfvlab=default
opnfvlabfile=
opnfvrel=e
opnfvfeature=none
opnfvdistro=xenial
opnfvarch=amd64
opnfvmodel=openstack
virtinstall=0
maasinstall=0

usage() { echo "Usage: $0
    [-s|--sdn <nosdn|odl|ocl>]
    [-t|--type <noha|ha|tip>]
    [-o|--openstack <ocata|queens>]
    [-l|--lab <default|custom>]
    [-f|--feature <ipv6,dpdk,lxd,dvr,openbaton,multus>]
    [-d|--distro <xenial>]
    [-a|--arch <amd64|ppc64el|aarch64>]
    [-m|--model <openstack|kubernetes>]
    [-i|--virtinstall <0|1>]
    [--maasinstall <0|1>]
    [--labfile <labconfig.yaml file>]
    [-r|--release <e>]" 1>&2 exit 1;
}

#A string with command options
options=$@

# An array with all the arguments
arguments=($options)

# Loop index
index=0

for argument in $options
    do
        # Incrementing index
        index=`expr $index + 1`

        # The conditions
        case $argument in
            -h|--help )
                usage;
                ;;
            -s|--sdn  )
                if ([ "arguments[index]" != "" ]); then
                    opnfvsdn=${arguments[index]}
                fi;
                ;;
            -t|--type )
                if ([ "arguments[index]" != "" ]); then
                    opnfvtype=${arguments[index]}
                fi;
                ;;
            -o|--openstack )
                if ([ "arguments[index]" != "" ]); then
                    openstack=${arguments[index]}
                fi;
                ;;

            -l|--lab  )
                if ([ "arguments[index]" != "" ]); then
                    opnfvlab=${arguments[index]}
                fi;
                ;;

            -r|--release )
                if ([ "arguments[index]" != "" ]); then
                    opnfvrel=${arguments[index]}
                fi;
                ;;

            -f|--feature )
                if ([ "arguments[index]" != "" ]); then
                    opnfvfeature=${arguments[index]}
                fi;
                ;;

            -d|--distro )
                if ([ "arguments[index]" != "" ]); then
                    opnfvdistro=${arguments[index]}
                fi;
                ;;

            -a|--arch  )
                if ([ "arguments[index]" != "" ]); then
                    opnfvarch=${arguments[index]}
                fi;
                ;;

            -m|--model )
                if ([ "arguments[index]" != "" ]); then
                    opnfvmodel=${arguments[index]}
                fi;
                ;;

            -i|--virtinstall )
                if ([ "arguments[index]" != "" ]); then
                    virtinstall=${arguments[index]}
                fi;
                ;;
            --maasinstall )
                if ([ "arguments[index]" != "" ]); then
                    maasinstall=${arguments[index]}
                fi;
                ;;
            --labfile )
                if ([ "arguments[index]" != "" ]); then
                    labfile=${arguments[index]}
                fi;
                ;;
          esac
    done


#by default maas creates two VMs in case of three more VM needed.
createresource() {
    # TODO: make sure this function run with the same parameters used in 03-maasdeploy.sh
    PROFILE=${PROFILE:-ubuntu}
    MAAS_IP=$(grep " ip_address" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //')
    API_SERVER="http://$MAAS_IP:5240/MAAS/api/2.0"
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVER $API_KEY

   # if we have a virshurl configuration we use it, else we use local
    VIRSHURL=$(cat labconfig.json | jq -r '.opnfv.virshurl')
    if ([ $VIRSHURL == "" ] || [ "$VIRSHURL" == "null" ]); then
        VIRSHIP=$MAAS_IP
        VIRSHURL="qemu+ssh://$USER@$VIRSHIP/system "
        VIRSHHOST=""
    else
        VIRSHHOST=$(echo $VIRSHURL| cut -d\/ -f 3 | cut -d@ -f2)
        VIRSHIP=""  # TODO: parse from $VIRSHURL if needed
    fi

    for node in node3-control node4-control
    do
        node_id=$(maas $PROFILE machines read | \
                  jq -r ".[] | select(.hostname == \"$node\").system_id")
        if [[ -z "$node_id" ]]; then
            sudo virt-install --connect qemu:///system --name $node \
                --ram 8192 --cpu host --vcpus 4 \
                --disk size=120,format=qcow2,bus=virtio,cache=directsync,io=native,pool=default \
                --network bridge=virbr0,model=virtio \
                --network bridge=virbr0,model=virtio \
                --boot network,hd,menu=off \
                --noautoconsole --vnc --print-xml | tee _node.xml
            node_mac=$(grep "mac address" _node.xml | head -1 | cut -d "'" -f 2)
            sudo virsh -c $VIRSHURL define --file _node.xml
            rm -f _node.xml

            maas $PROFILE nodes new autodetect_nodegroup='yes' name=$node \
                tags='control' hostname=$name power_type='virsh' \
                mac_addresses=$node3controlmac \
                power_parameters_power_address="qemu+ssh://$USER@192.168.122.1/system" \
                architecture='amd64/generic' power_parameters_power_id='node3-control'
            sudo virsh -c $VIRSHURL autostart $node
            node_id=$(maas $PROFILE machines read | \
                  jq -r ".[] | select(.hostname == \"$node\").system_id")
        fi
        if [[ -z "$node_id" ]]; then
            echo_error "Error: failed to create node $node ."
            exit 1
        fi
        maas $PROFILE tag update-nodes control add=$node_id || true
    done
}

#copy the files and create extra resources needed for HA deployment
# in case of default VM labs.
deploy() {
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
            if [ "$maasinstall" -eq 0 ]; then
                echo_error "MAAS not deployed please deploy MAAS first."
            else
                echo_info "MAAS not deployed this will deploy MAAS first."
            fi
        fi
    fi

    # Install MAAS and expecting the labconfig.yaml at local directory.

    if [ "$maasinstall" -eq 1 ]; then
        ./clean.sh || true
        PROFILE=${PROFILE:-ubuntu}
        MAAS_IP=$(grep " ip_address" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //')
        API_SERVER="http://$MAAS_IP:5240/MAAS/api/2.0"
        if which maas > /dev/null; then
            API_KEY=`sudo maas-region apikey --username=ubuntu`
            maas login $PROFILE $API_SERVER $API_KEY

            # make sure there is no machine entry in maas
            for m in $(maas $PROFILE machines read | jq -r '.[].system_id')
            do
                maas $PROFILE machine delete $m || true
            done
            podno=$(maas $PROFILE pods read | jq -r ".[]".id)
            maas $PROFILE pod delete $podno || true
        fi
        ./cleanvm.sh || true

        if [ "$virtinstall" -eq 1 ]; then
            ./03-maasdeploy.sh virtual
        else
            if [ -z "$labfile" ]; then
                if [ ! -e ./labconfig.yaml ]; then
                    echo_error "Labconfig file must be specified when using custom"
                else
                    echo_warning "Labconfig was not specified, using ./labconfig.yaml instead"
                fi
            elif [ ! -e "$labfile" ]; then
                echo_warning "Labconfig not found locally, trying download"
                wget $labfile -t 3 -T 10 -O ./labconfig.yaml || true
                count=`wc -l labconfig.yaml  | cut -d " " -f 1`
                if [ $count -lt 10 ]; then
                    echo_error "Unable to download labconfig"
                    exit 1
                fi
            else
                echo_info "Using $labfile to setup deployment"
                cp $labfile ./labconfig.yaml
            fi

            ./03-maasdeploy.sh custom
        fi
    fi

    #create json file which is missing in case of new deployment after maas and git tree cloned freshly.
    python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < labconfig.yaml > labconfig.json
    python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < deployconfig.yaml > deployconfig.json

    if [[ "$opnfvtype" = "ha" && "$opnfvlab" = "default" ]]; then
        createresource
    fi

    #bootstrap the node
    ./01-bootstrap.sh $opnfvdistro

    juju model-config default-series=$opnfvdistro enable-os-refresh-update=false enable-os-upgrade=false
    juju set-model-constraints tags=

    # case default deploy the opnfv platform:
    ./02-deploybundle.sh $opnfvtype $openstack $opnfvlab $opnfvsdn $opnfvfeature $opnfvdistro $opnfvmodel
}

#check whether charms are still executing the code even juju-deployer says installed.
check_status() {
    waitstatus=$1
    waittime=$2
    retval=0
    timeoutiter=0

    echo_info "Executing the relationships within charms..."
    while [ $retval -eq 0 ]; do
        if juju status | grep -q $waitstatus; then
           echo_info "Still waiting for $waitstatus units"
           if [ $timeoutiter -ge $waittime ]; then
               echo_error 'Timed out'
               retval=1
           else
               sleep 30
           fi
           timeoutiter=$((timeoutiter+1))
       else
           echo_info 'Done executing the relationships'
           retval=1
       fi
    done

    if [[ "$opnfvmodel" = "openstack" ]]; then
        juju expose ceph-radosgw || true
        #juju ssh ceph/0 \ 'sudo radosgw-admin user create --uid="ubuntu" --display-name="Ubuntu Ceph"'
    fi

    echo_info "Deployment finishing..."
 }


# In the case of a virtual deployment
if [ "$virtinstall" -eq 1 ]; then
    ./clean.sh || true
fi

echo_info "Deployment started"
deploy

check_status executing 180

echo_info "Deployment finished"
juju status --format=tabular

# translate bundle.yaml to json
python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < bundles.yaml > bundles.json

# Configuring deployment
if ([ $opnfvmodel == "openstack" ]); then

    echo_info "Configuring OpenStack deployment"

    ./openstack.sh "$opnfvsdn" "$opnfvlab" "$opnfvdistro" "$openstack" || true

    # creating heat domain after pushing the public API into /etc/hosts
    status=`juju run-action heat/0 domain-setup`
    echo $status
    if  ([ $opnfvsdn != "ocl" ]) then
      status=`juju run-action ceilometer/0 ceilometer-upgrade`
    fi
    echo $status
    if ([ $opnftype == "ha" ]); then
        status=`juju run-action heat/1 domain-setup`
        echo $status
        if  ([ $opnfvsdn != "ocl" ]) then
          status=`juju run-action ceilometer/1 ceilometer-upgrade`
        fi
        echo $status
        status=`juju run-action heat/2 domain-setup`
        echo $status
        if  ([ $opnfvsdn != "ocl" ]) then
          status=`juju run-action ceilometer/2 ceilometer-upgrade`
        fi
        echo $status
    fi

    sudo ../juju/get-cloud-images || true
    ../juju/joid-configure-openstack || true

    if grep -q 'openbaton' bundles.yaml; then
        juju add-relation openbaton keystone
    fi

elif ([ $opnfvmodel == "kubernetes" ]); then
   #Workarounf for master chanrm as it takes 5 minutes to run properly
    check_status waiting 50
    check_status executing 50
    echo_info "Configuring Kubernetes deployment"

    ./k8.sh $opnfvfeature
fi

# expose the juju gui-url to login into juju gui

echo_info "Juju GUI can be accessed using the following URL and credentials:"
juju gui --show-credentials --no-browser

echo "Finished deployment and configuration"
