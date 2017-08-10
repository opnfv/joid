#!/bin/bash
#placeholder for deployment script.
set -ex

source tools.sh

virtinstall=0
labname=$1

if [ ! -e $HOME/.ssh/id_rsa ]; then
    ssh-keygen -N '' -f $HOME/.ssh/id_rsa
fi

NODE_ARCTYPE=`arch`
NODE_ARC="amd64/generic"

if [ "x86_64" == "$NODE_ARCTYPE" ]; then
    NODE_ARC="amd64/generic"
elif  [ "ppc64le" == "$NODE_ARCTYPE" ]; then
    NODE_ARC='ppc64el'
else
    NODE_ARC=$NODE_ARCTYPE
fi

# Install the packages needed
echo_info "Installing and upgrading required packages"
sudo apt-get install software-properties-common -y
sudo apt-add-repository ppa:juju/stable -y
sudo apt-add-repository ppa:maas/stable -y
sudo apt-add-repository cloud-archive:ocata -y
sudo apt-get update -y
#sudo apt-get dist-upgrade -y
sudo apt-get install bridge-utils openssh-server bzr git virtinst qemu-kvm libvirt-bin \
             maas maas-region-controller juju python-pip python-psutil python-openstackclient \
             python-congressclient gsutil charm-tools pastebinit python-jinja2 sshpass \
             openssh-server vlan ipmitool jq expect snap -y

#sudo apt-get install snap -y
#sudo snap install maas --classic
#sudo snap install juju --classic

sudo -H pip install --upgrade pip

#first parameter should be custom and second should be either
# absolute location of file (including file name) or url of the
# file to download.


#
# Config preparation
#

# Get labconfig and generate deployconfig.yaml
echo_info "Parsing lab configuration file"
case "$labname" in
    intelpod[569]|orangepod[12]|cengnpod[12] )
        array=(${labname//pod/ })
        cp ../labconfig/${array[0]}/pod${array[1]}/labconfig.yaml .
        python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
        ;;
    'attvirpod1' )
        cp ../labconfig/att/virpod1/labconfig.yaml .
        python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
        ;;
    'custom')
        labfile=$2
        if [ -e $labfile ]; then
            cp $labfile ./labconfig.yaml || true
        else
            wget $labconfigfile -t 3 -T 10 -O ./labconfig.yaml || true
            count=`wc -l labconfig.yaml  | cut -d " " -f 1`
            if [ $count -lt 10 ]; then
                rm -rf labconfig.yaml
            fi
        fi
        if [ ! -e ./labconfig.yaml ]; then
            virtinstall=1
            labname="default"
            cp ../labconfig/default/labconfig.yaml ./
            cp ../labconfig/default/deployconfig.yaml ./
        else
            python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
            labname=`grep "maas_name" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
        fi
        ;;
    * )
        virtinstall=1
        labname="default"
        cp ../labconfig/default/labconfig.yaml ./
        python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
        ;;
esac

python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < labconfig.yaml > labconfig.json
python -c 'import sys, yaml, json; json.dump(yaml.load(sys.stdin), sys.stdout, indent=4)' < deployconfig.yaml > deployconfig.json

MAAS_IP=$(grep " ip_address" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //')
MAAS_NAME=`grep "maas_name" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
API_SERVER="http://$MAAS_IP:5240/MAAS/api/2.0"
API_SERVERMAAS="http://$MAAS_IP:5240/MAAS/"
PROFILE=ubuntu
MY_UPSTREAM_DNS=`grep "upstream_dns" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
SSH_KEY=`cat ~/.ssh/id_rsa.pub`
MAIN_ARCHIVE=`grep "main_archive" deployconfig.yaml | cut -d ':' -f 2-3 | sed -e 's/ //'`
URL=https://images.maas.io/ephemeral-v3/daily/
KEYRING_FILE=/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg
SOURCE_ID=1
FABRIC_ID=1
PRIMARY_RACK_CONTROLLER="$MAAS_IP"
VLAN_UNTTAGED="untagged"

# In the case of a virtual deployment get deployconfig.yaml
if [ "$virtinstall" -eq 1 ]; then
    ./cleanvm.sh || true
fi

#create backup directory
mkdir ~/joid_config/ || true

# Backup deployconfig.yaml in joid_config folder

if [ -e ./deployconfig.yaml ]; then
    cp ./deployconfig.yaml ~/joid_config/
    cp ./labconfig.yaml ~/joid_config/
fi

#
# Prepare local environment to avoid password asking
#

# make sure no password asked during the deployment.
sudoer_file=/etc/sudoers.d/90-joid-init
sudoer_entry="$USER ALL=(ALL) NOPASSWD:ALL"
if [ -e $sudoer_file ]; then
    if ! sudo grep -q "$sudoer_entry" $sudoer_file; then
        sudo sed -i -e "1i$sudoer_entry" $sudoer_file
    fi
else
    echo "$sudoer_entry" > 90-joid-init
    sudo chown root:root 90-joid-init
    sudo mv 90-joid-init /etc/sudoers.d/
fi

echo_info "Deployment of MAAS started"

#
# Virsh preparation
#

# define the pool and try to start even though its already exist.
# For fresh install this may or may not there.
#some system i am seeing libvirt and some have libvirtd looks like libvirt-bin is
#keep switching so lets try both.

sudo adduser $USER libvirtd || true
sudo adduser $USER libvirt || true
sudo virsh pool-define-as default --type dir --target /var/lib/libvirt/images/ || true
sudo virsh pool-start default || true
sudo virsh pool-autostart default || true

# In case of virtual install set network
if [ "$virtinstall" -eq 1 ]; then
    sudo virsh net-dumpxml default > default-net-org.xml
    sed -i '/dhcp/d' default-net-org.xml
    sed -i '/range/d' default-net-org.xml
    sudo virsh net-destroy default
    sudo virsh net-define default-net-org.xml
    sudo virsh net-start default
    rm -f default-net-org.xml
fi

#
# Cleanup, juju init and config backup
#

# To avoid problem between apiclient/maas_client and apiclient from google
# we remove the package google-api-python-client from yardstick installer
if [ $(pip list --format=columns | grep google-api-python-client | wc -l) == 1 ]; then
    sudo pip uninstall google-api-python-client
fi


if [ ! -e ~maas/.ssh/id_rsa.pub ]; then
    if [ ! -e $HOME/id_rsa_maas.pub ]; then
        [ -e $HOME/id_rsa_maas ] && rm -f $HOME/id_rsa_maas
        sudo su - $USER -c "echo |ssh-keygen -t rsa -f $HOME/id_rsa_maas"
    fi
    sudo -u maas mkdir ~maas/.ssh/ || true
    sudo cp $HOME/id_rsa_maas ~maas/.ssh/id_rsa
    sudo cp $HOME/id_rsa_maas.pub ~maas/.ssh/id_rsa.pub
    sudo chown maas:maas ~maas/.ssh/id_rsa
    sudo chown maas:maas ~maas/.ssh/id_rsa.pub
fi

# Ensure virsh can connect without ssh auth
sudo cat ~maas/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
sudo cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys

#
# MAAS deploy
#

installmaas(){
    sudo apt-get install maas maas-region-controller -y
}

#
# MAAS config
# https://insights.ubuntu.com/2016/01/23/maas-setup-deploying-openstack-on-maas-1-9-with-juju/
# http://blog.naydenov.net/2016/01/nodes-networking-deploying-openstack-on-maas-1-9-with-juju/
#
configuremaas(){
    #reconfigure maas with correct MAAS address.
    #Below code is needed as MAAS have issue in commisoning without restart.
    #sudo ./maas-reconfigure-region.sh $MAAS_IP
    sleep 30
    sudo maas-rack config --region-url http://$MAAS_IP:5240/MAAS

    sudo maas createadmin --username=ubuntu --email=ubuntu@ubuntu.com --password=ubuntu || true
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY
    maas $PROFILE maas set-config name='main_archive' value=$MAIN_ARCHIVE || true
    maas $PROFILE maas set-config name=upstream_dns value=$MY_UPSTREAM_DNS || true
    maas $PROFILE maas set-config name='maas_name' value=$MAAS_NAME || true
    maas $PROFILE maas set-config name='ntp_server' value='ntp.ubuntu.com' || true
    maas $PROFILE sshkeys create "key=$SSH_KEY" || true

    for tag in bootstrap compute control storage
    do
        maas $PROFILE tags create name=$tag || true
    done

    #create the required spaces.
    maas $PROFILE space update 0 name=default || true
    for space in unused admin-api internal-api public-api compute-data \
                 compute-external storage-data storage-cluster admin \
                 tenant-data tenant-api tenant-public
    do
        echo_info "Creating the space $space"
        maas $PROFILE spaces create name=$space || true
    done

    maas $PROFILE boot-source update $SOURCE_ID \
         url=$URL keyring_filename=$KEYRING_FILE || true

    maas $PROFILE boot-resources import || true

    while [ "$(maas $PROFILE boot-resources is-importing)" == "true" ];
    do
        sleep 60
    done
}

setupspacenetwork(){

    #get space, subnet and vlan and create accordingly.
    #for type in admin data storage external floating public; do
    nettypes=`cat labconfig.json | jq '.opnfv.spaces[]'.type | cut -d \" -f 2`
    for type in $nettypes; do
        config_done=0
        SPACE_CIDR=`cat labconfig.json | jq '.opnfv.spaces[] | select(.type=="'$type'")'.cidr | cut -d \" -f 2 `
        SPACE_VLAN=`cat labconfig.json | jq '.opnfv.spaces[] | select(.type=="'$type'")'.vlan | cut -d \" -f 2 `
        SPACE_GWAY=`cat labconfig.json | jq '.opnfv.spaces[] | select(.type=="'$type'")'.gateway | cut -d \" -f 2 `
        NET_FABRIC_NAME=$(maas $PROFILE subnets read | jq -r ".[] |  select(.cidr==\"$SPACE_CIDR\")".vlan.fabric)
        if ([ $NET_FABRIC_NAME ] && [ $NET_FABRIC_NAME != "null" ]); then
            NET_FABRIC_VID=$(maas $PROFILE subnets read | jq -r ".[] |  select(.cidr==\"$SPACE_CIDR\")".vlan.vid)
            NET_FABRIC_ID=$(maas $PROFILE fabric read $NET_FABRIC_NAME | jq -r ".id")
            if ([ $SPACE_VLAN == "null" ]); then
                SPACE_VLAN=0
            fi
            NET_VLAN_ID=$(maas $PROFILE vlans read $NET_FABRIC_ID | jq -r ".[] |  select(.vid==\"$SPACE_VLAN\")".id)
            NET_VLAN_VID=$(maas $PROFILE vlans read $NET_FABRIC_ID | jq -r ".[] |  select(.vid==\"$SPACE_VLAN\")".vid)
            if ([ $SPACE_GWAY ] && [ "$SPACE_GWAY" != "null" ]); then
                maas $PROFILE subnet update $SPACE_CIDR gateway_ip=$SPACE_GWAY
            fi
            if ([ $NET_VLAN_VID ] && [ $NET_VLAN_VID == "0" ]); then
                config_done=1
            elif ([ $NET_VLAN_VID ] && [ $NET_VLAN_VID == $SPACE_VLAN ]); then
                config_done=1
            else
                NET_VLAN_ID=$(maas $PROFILE vlans create $NET_FABRIC_ID vid=$SPACE_VLAN | jq --raw-output ".id")
                if ([ $NET_VLAN_ID ] && [ $NET_VLAN_ID != "null" ]); then
                    maas $PROFILE subnet update $SPACE_CIDR vlan=$NET_VLAN_ID
                    NET_FABRIC_VID=$SPACE_VLAN
                fi
            fi
        else
            if ([ $SPACE_CIDR ] && [ "$SPACE_CIDR" != "null" ]); then
                FABRIC_ID=$(maas $PROFILE fabrics create name=opnfv$type | jq --raw-output ".id")
                NET_FABRIC_ID=$FABRIC_ID
                NET_FABRIC_VID=$SPACE_VLAN
                if ([ $SPACE_VLAN ] && [ "$SPACE_VLAN" != "null" ]); then
                    NET_VLAN_ID=$(maas $PROFILE vlans create $FABRIC_ID vid=$SPACE_VLAN | jq --raw-output ".id")
                    if ([ $SPACE_GWAY ] && [ "$SPACE_GWAY" != "null" ]); then
                        maas $PROFILE subnets create fabric=$FABRIC_ID cidr=$SPACE_CIDR vid=$VID_ID gateway_ip=$SPACE_GWAY
                    else
                        maas $PROFILE subnets create fabric=$FABRIC_ID cidr=$SPACE_CIDR vid=$VID_ID
                    fi
                    NET_FABRIC_VID=$VLAN_ID
                else
                    if ([ $SPACE_GWAY ] && [ "$SPACE_GWAY" != "null" ]); then
                        maas $PROFILE subnets create fabric=$FABRIC_ID cidr=$SPACE_CIDR vid="0" gateway_ip=$SPACE_GWAY
                    else
                        maas $PROFILE subnets create fabric=$FABRIC_ID cidr=$SPACE_CIDR vid="0"
                    fi
                fi
                NET_FABRIC_NAME=$(maas $PROFILE subnets read | jq -r ".[] |  select(.cidr==\"$SPACE_CIDR\")".vlan.fabric)
            fi
        fi
        case "$type" in
            'admin')           JUJU_SPACE="internal-api";  DHCP='enabled' ;;
            'data')            JUJU_SPACE="tenant-data";   DHCP='' ;;
            'public')          JUJU_SPACE="public-api";    DHCP='' ;;
            'storage')         JUJU_SPACE="tenant-stor";   DHCP='' ;;
            'storagecluster')  JUJU_SPACE="storclus";      DHCP='' ;;
            'floating')        JUJU_SPACE="tenant-public"; DHCP='' ;;
            *)                 JUJU_SPACE='default';       DHCP='OFF'; echo_info "      >>> Unknown SPACE" ;;
        esac
        JUJU_SPACE_ID=$(maas $PROFILE spaces read | jq -r ".[] |  select(.name==\"$JUJU_SPACE\")".id)
        JUJU_VLAN_VID=$(maas $PROFILE subnets read | jq -r ".[] |  select(.name==\"$SPACE_CIDR\")".vlan.vid)
        NET_FABRIC_ID=$(maas $PROFILE fabric read $NET_FABRIC_NAME | jq -r ".id")
        if ([ $NET_FABRIC_ID ] && [ $NET_FABRIC_ID != "null" ]); then
            if ([ $JUJU_VLAN_VID ] && [ $JUJU_VLAN_VID != "null" ]); then
                maas $PROFILE vlan update $NET_FABRIC_ID $JUJU_VLAN_VID space=$JUJU_SPACE_ID
            fi
        fi
        if ([ $type == "admin" ]); then
                    # If we have a network, we create it
            if ([ $NET_FABRIC_ID ]); then
                # Set ranges
                SUBNET_PREFIX=${SPACE_CIDR::-5}
                IP_RES_RANGE_LOW="$SUBNET_PREFIX.1"
                IP_RES_RANGE_HIGH="$SUBNET_PREFIX.39"
                IP_DYNAMIC_RANGE_LOW="$SUBNET_PREFIX.40"
                IP_DYNAMIC_RANGE_HIGH="$SUBNET_PREFIX.150"
                maas $PROFILE ipranges create type=reserved \
                     start_ip=$IP_RES_RANGE_LOW end_ip=$IP_RES_RANGE_HIGH \
                     comment='This is a reserved range' || true
                maas $PROFILE ipranges create type=dynamic \
                    start_ip=$IP_DYNAMIC_RANGE_LOW end_ip=$IP_DYNAMIC_RANGE_HIGH \
                    comment='This is a reserved dynamic range' || true
                # Set DHCP
                PRIMARY_RACK_CONTROLLER=$(maas $PROFILE rack-controllers read | jq -r '.[0].system_id')
                maas $PROFILE vlan update $NET_FABRIC_ID $NET_FABRIC_VID dhcp_on=True primary_rack=$PRIMARY_RACK_CONTROLLER || true
            fi
        fi
    done
}

addnodes(){
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY

    # make sure there is no machine entry in maas
    for m in $(maas $PROFILE machines read | jq -r '.[].system_id')
    do
        maas $PROFILE machine delete $m
    done

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

    if [ "$virtinstall" -eq 1 ]; then
        netw=" --network bridge=virbr0,model=virtio"
    elif ([ $VIRSHHOST != "" ]); then
        # Get the bridge hosting the remote virsh
        brid=$(ssh $VIRSHHOST "ip a l | grep $VIRSHHOST | perl -pe 's/.* (.*)\$/\$1/g'")
        netw=" --network bridge=$brid,model=virtio"
        # prepare a file containing virsh remote url to connect without adding it n command line
        echo "export VIRSH_DEFAULT_CONNECT_URI=$VIRSHURL" > virsh_uri.sh
    else
        netw=""

        brid=`brctl show | grep 8000 | cut -d "8" -f 1 |  tr "\n" " " | tr "    " " " | tr -s " "`
        ADMIN_BR=`cat labconfig.json | jq '.opnfv.spaces[] | select(.type=="admin")'.bridge | cut -d \" -f 2 `

        for feature in $brid; do
            if [ "$feature" == "$ADMIN_BR" ]; then
                netw=$netw" --network bridge="$feature",model=virtio"
            else
                netw=$netw
            fi
        done
    fi

    # Add server fingerprint to known hosts to prevent security prompt in the
    # SSH connection during the virt-install
    if [ $VIRSHIP != "" ]; then
        # Check if the IP is not already present among the known hosts
        if ! ssh-keygen -F $VIRSHIP > /dev/null ; then
            echo_info "SSH fingerprint of the host is not known yet, adding to known_hosts"
            ssh-keyscan -H $VIRSHIP >> ~/.ssh/known_hosts
        fi
    fi

    echo_info "Creating and adding bootstrap node"

    virt-install --connect $VIRSHURL --name bootstrap --ram 4098 --cpu host --vcpus 2 --video \
                 cirrus --disk size=20,format=qcow2,bus=virtio,cache=directsync,io=native,pool=default \
                 $netw --boot network,hd,menu=off --noautoconsole \
                 --vnc --print-xml | tee bootstrap

    if [ "$virtinstall" -eq 1 ]; then
        bootstrapmac=`grep  "mac address" bootstrap | head -1 | cut -d '"' -f 2`
    else
        bootstrapmac=""
        bootstrapmacs=`grep  "mac address" bootstrap| cut -d '"' -f 2`
        for mac in $bootstrapmacs; do
            bootstrapmac=$bootstrapmac" mac_addresses="$mac
        done
    fi
    virsh -c $VIRSHURL define --file bootstrap
    rm -f bootstrap

    sleep 60

    maas $PROFILE machines create autodetect_nodegroup='yes' name='bootstrap' \
        tags='bootstrap' hostname='bootstrap' power_type='virsh' mac_addresses=$bootstrapmac \
        power_parameters_power_address="$VIRSHURL" \
        architecture=$NODE_ARC power_parameters_power_id='bootstrap'

    bootstrapid=$(maas $PROFILE machines read | jq -r '.[] | select(.hostname == "bootstrap").system_id')

    maas $PROFILE tag update-nodes bootstrap add=$bootstrapid

    if [ "$virtinstall" -eq 1 ]; then
        units=`cat deployconfig.json | jq .opnfv.units`

        until [ $(($units)) -lt 1 ]; do
           units=$(($units - 1));
           NODE_NAME=`cat labconfig.json | jq ".lab.racks[].nodes[$units].name" | cut -d \" -f 2 `

            virt-install --connect $VIRSHURL --name $NODE_NAME --ram 8192 --cpu host --vcpus 4 \
                     --disk size=120,format=qcow2,bus=virtio,cache=directsync,io=native,pool=default \
                     $netw $netw --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee $NODE_NAME

            nodemac=`grep  "mac address" $NODE_NAME | head -1 | cut -d '"' -f 2`
            virsh -c $VIRSHURL define --file $NODE_NAME
            rm -f $NODE_NAME
            maas $PROFILE machines create autodetect_nodegroup='yes' name=$NODE_NAME \
                tags='control compute' hostname=$NODE_NAME power_type='virsh' mac_addresses=$nodemac \
                power_parameters_power_address="$VIRSHURL" \
                architecture=$NODE_ARC power_parameters_power_id=$NODE_NAME
            nodeid=$(maas $PROFILE machines read | jq -r '.[] | select(.hostname == '\"$NODE_NAME\"').system_id')
            maas $PROFILE tag update-nodes control add=$nodeid || true
            maas $PROFILE tag update-nodes compute add=$nodeid || true
        done
    else
        units=`cat deployconfig.json | jq .opnfv.units`

        until [ $(($units)) -lt 1 ]; do
            units=$(($units - 1));
            NODE_NAME=`cat labconfig.json | jq ".lab.racks[].nodes[$units].name" | cut -d \" -f 2 `
            MAC_ADDRESS=`cat labconfig.json | jq ".lab.racks[].nodes[$units].nics[] | select(.spaces[]==\"admin\").mac"[0] | cut -d \" -f 2 `
            #MAC_ADDRESS1=`cat labconfig.json | jq ".lab.racks[].nodes[$units].nics[] | select(.spaces[]==\"floating\").mac"[0] | cut -d \" -f 2 `
            POWER_TYPE=`cat labconfig.json | jq ".lab.racks[].nodes[$units].power.type" | cut -d \" -f 2 `
            POWER_IP=`cat labconfig.json |  jq ".lab.racks[].nodes[$units].power.address" | cut -d \" -f 2 `
            POWER_USER=`cat labconfig.json |  jq ".lab.racks[].nodes[$units].power.user" | cut -d \" -f 2 `
            POWER_PASS=`cat labconfig.json |  jq ".lab.racks[].nodes[$units].power.pass" | cut -d \" -f 2 `
            NODE_ARCTYPE=`cat labconfig.json |  jq ".lab.racks[].nodes[$units].architecture" | cut -d \" -f 2 `

            if [ "x86_64" == "$NODE_ARCTYPE" ]; then
                NODE_ARC="amd64/generic"
            elif  [ "ppc64le" == "$NODE_ARCTYPE" ]; then
                NODE_ARC='ppc64el'
            else
                NODE_ARC=$NODE_ARCTYPE
            fi

            echo_info "Creating node $NODE_NAME"
            maas $PROFILE machines create autodetect_nodegroup='yes' name=$NODE_NAME \
                hostname=$NODE_NAME power_type=$POWER_TYPE power_parameters_power_address=$POWER_IP \
                power_parameters_power_user=$POWER_USER power_parameters_power_pass=$POWER_PASS mac_addresses=$MAC_ADDRESS \
                architecture=$NODE_ARC
        done
    fi

    maas $PROFILE pods create type=virsh power_address="$VIRSHURL" power_user=$USER

    # Make sure nodes are added into MAAS and none of them is in commissioning state
    i=0
    while [ "$(maas $PROFILE nodes read | grep Commissioning )" ];
    do
        echo_info "Waiting for nodes to finish commissioning. ${i} minutes elapsed."
        sleep 60
        i=$[$i+1]

        # Make sure that no nodes have failed commissioning or testing
        if [ "$(maas $PROFILE nodes read | grep 'Failed' )" ];
        then
            echo "Error: Some nodes have failed commissioning or testing" 1>&2
            exit 1
        fi

    done

}

# configure MAAS with the different options.
configuremaas
sleep 30

# functioncall with subnetid to add and second parameter is dhcp enable
# third parameter will define the space. It is required to have admin

setupspacenetwork

#just make sure rack controller has been synced and import only
# just whether images have been imported or not.
sudo ./maas-reconfigure-region.sh $MAAS_IP
sleep 120

# Let's add the nodes now. Currently works only for virtual deployment.
addnodes

echo_info "Initial deployment of MAAS finished"

#Added the Qtip public to run the Qtip test after install on bare metal nodes.
#maas $PROFILE sshkeys new key="`cat ./maas/sshkeys/QtipKey.pub`"
#maas $PROFILE sshkeys new key="`cat ./maas/sshkeys/DominoKey.pub`"

addcredential() {
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`
    cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`

    echo  "credentials:" > credential.yaml
    echo  "  $controllername:" >> credential.yaml
    echo  "    opnfv-credentials:" >> credential.yaml
    echo  "      auth-type: oauth1" >> credential.yaml
    echo  "      maas-oauth: $API_KEY" >> credential.yaml

    juju add-credential $controllername -f credential.yaml --replace
}

addcloud() {
    controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`
    cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`

    echo "clouds:" > maas-cloud.yaml
    echo "   $cloudname:" >> maas-cloud.yaml
    echo "      type: maas" >> maas-cloud.yaml
    echo "      auth-types: [oauth1]" >> maas-cloud.yaml
    echo "      endpoint: $API_SERVERMAAS" >> maas-cloud.yaml

    echo_info "Adding cloud $cloudname"
    juju add-cloud $cloudname maas-cloud.yaml --replace
}

#
# Enable MAAS nodes interfaces
#
API_KEY=`sudo maas-region apikey --username=ubuntu`
maas login $PROFILE $API_SERVERMAAS $API_KEY

if [ -e ./labconfig.json ]; then
    # We will configure all node, so we need the qty, and loop on it
    NODE_QTY=$(cat labconfig.json | jq --raw-output '.lab.racks[0].nodes[]'.name | wc -l)
    NODE_QTY=$((NODE_QTY-1))
    for NODE_ID in $(seq 0 $NODE_QTY); do
        # Get the NAME/SYS_ID of this node
        NODE_NAME=$(cat labconfig.json | jq --raw-output ".lab.racks[0].nodes[$NODE_ID].name")
        NODE_SYS_ID=$(maas $PROFILE nodes read | jq -r ".[] |  select(.hostname==\"$NODE_NAME\")".system_id)
        echo_info ">>> Configuring node $NODE_NAME [$NODE_ID][$NODE_SYS_ID]"
        # Recover the network interfaces list and configure each one
        #   with sorting the list, we have hardware interface first, than the vlan interfaces
        IF_LIST=$(cat labconfig.json | jq --raw-output ".lab.racks[0].nodes[$NODE_ID].nics[] ".ifname | sort -u )
        for IF_NAME in $IF_LIST; do
            # get the space of the interface
            IF_SPACE=$(cat labconfig.json | jq --raw-output ".lab.racks[0].nodes[$NODE_ID].nics[] | select(.ifname==\"$IF_NAME\") ".spaces[])
            SUBNET_CIDR=`cat labconfig.json | jq '.opnfv.spaces[] | select(.type=="'$IF_SPACE'")'.cidr | cut -d \" -f 2 `
            case "$IF_SPACE" in
                'data')     IF_MODE='AUTO' ;;
                'public')   IF_MODE='AUTO' ;;
                'storage')  IF_MODE='AUTO' ;;
                'floating') IF_MODE='link_up' ;;
                *) SUBNET_CIDR='null'; IF_MODE='null'; echo_info "      >>> Unknown SPACE" ;;
            esac
            echo_info "   >>> Configuring interface $IF_NAME [$IF_SPACE][$SUBNET_CIDR]"

            # if we have a vlan parameter in the space config
            IF_VLAN=$(cat labconfig.json | jq --raw-output ".opnfv.spaces[] | select(.type==\"$IF_SPACE\")".vlan)
            if ([ -z $IF_VLAN ] && [ $IF_NAME =~ \. ]); then
                # We have no vlan specified on spaces, but we have a vlan subinterface
                IF_VLAN = ${IF_NAME##*.}; fi

            # in case of interface renaming
            IF_NEWNAME=$IF_NAME

            # In case of a VLAN interface
            if ([ $IF_VLAN ] && [ "$IF_VLAN" != "null" ]); then
                echo_info "      >>> Configuring VLAN $IF_VLAN"
                VLANID=$(maas $PROFILE subnets read | jq ".[].vlan | select(.vid==$IF_VLAN)".id)
                FABRICID=$(maas $PROFILE subnets read | jq ".[].vlan | select(.vid==$IF_VLAN)".fabric_id)
                INTERFACE=$(maas $PROFILE interfaces read $NODE_SYS_ID | jq ".[] | select(.vlan.fabric_id==$FABRICID)".id)
                if [[ -z $INTERFACE ]]; then
                    # parent interface is not set because it does not have a SUBNET_CIDR
                    PARENT_VLANID=$(maas $PROFILE fabrics read | jq ".[].vlans[] | select(.fabric_id==$FABRICID and .name==\"untagged\")".id)
                    # If we need to rename the interface, use new interface name
                    if ([ $IF_NEWNAME ] && [ "$IF_NEWNAME" != "null" ]); then
                        PARENT_IF_NAME=${IF_NEWNAME%%.*}
                        IF_NAME=$IF_NEWNAME
                    else
                        PARENT_IF_NAME=${IF_NAME%%.*}
                    fi
                    # We set the physical interface to the targeted fabric
                    maas $PROFILE interface update $NODE_SYS_ID $PARENT_IF_NAME vlan=$PARENT_VLANID
                    sleep 2
                    INTERFACE=$(maas $PROFILE interfaces read $NODE_SYS_ID | jq ".[] | select(.vlan.fabric_id==$FABRICID)".id)
                fi
                maas $PROFILE interfaces create-vlan $NODE_SYS_ID vlan=$VLANID parent=$INTERFACE || true
            else
                # rename interface if needed
                IF_MACLOWER=$( cat labconfig.json | jq ".lab.racks[0].nodes[$NODE_ID].nics[] | select(.ifname==\"$IF_NEWNAME\")".mac[0])
                IF_MAC=(${IF_MACLOWER,,})
                IF_ID=$( maas $PROFILE interfaces read $NODE_SYS_ID | jq ".[] | select(.mac_address==$IF_MAC)".id)
                if ([ $IF_ID ] && [ "$IF_ID" != "null" ]); then
                    maas $PROFILE interface update $NODE_SYS_ID $IF_ID name=$IF_NEWNAME
                fi
            fi
            # Configure the interface
            if ([ $SUBNET_CIDR ] && [ "$SUBNET_CIDR" != "null" ]); then
                VLANID=$(maas $PROFILE subnet read $SUBNET_CIDR | jq -r '.vlan.id')
                if !([ $IF_VLAN ] && [ "$IF_VLAN" != "null" ]); then
                    # If this interface is not a VLAN (done withe create-vlan)
                    maas $PROFILE interface update $NODE_SYS_ID $IF_NAME vlan=$VLANID || true
                fi
                maas $PROFILE interface link-subnet $NODE_SYS_ID $IF_NAME  mode=$IF_MODE subnet=$SUBNET_CIDR || true
                sleep 2
            else
                echo_info "      >>> Not configuring, we have an empty Subnet CIDR"
            fi

        done
    done
fi

# Add the cloud and controller credentials for MAAS for that lab.
jujuver=`juju --version`

if [[ "$jujuver" > "2" ]]; then
    addcloud
    addcredential
fi

#
# End of scripts
#
echo_info " .... MAAS deployment finished successfully ...."
