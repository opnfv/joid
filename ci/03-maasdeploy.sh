#!/bin/bash
#placeholder for deployment script.
set -ex

virtinstall=0
labname=$1

if [ ! -e $HOME/.ssh/id_rsa ]; then
    ssh-keygen -N '' -f $HOME/.ssh/id_rsa
fi

#install the packages needed
sudo apt-add-repository ppa:juju/devel -y
sudo apt-add-repository ppa:maas/stable -y
sudo apt-add-repository cloud-archive:newton -y
sudo apt-get update -y
#sudo apt-get dist-upgrade -y
sudo apt-get install openssh-server bzr git virtinst qemu-kvm libvirt-bin juju \
             maas maas-region-controller python-pip python-psutil python-openstackclient \
             python-congressclient gsutil charm-tools pastebinit python-jinja2 sshpass \
             openssh-server vlan ipmitool jq expect -y

sudo pip install --upgrade pip

#first parameter should be custom and second should be either
# absolute location of file (including file name) or url of the
# file to download.


#
# Config preparation
#

# Get labconfig and generate deployconfig.yaml
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
API_SERVER="http://$MAAS_IP/MAAS/api/2.0"
API_SERVERMAAS="http://$MAAS_IP/MAAS/"
PROFILE=ubuntu
MY_UPSTREAM_DNS=`grep "upstream_dns" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
SSH_KEY=`cat ~/.ssh/id_rsa.pub`
MAIN_ARCHIVE=`grep "main_archive" deployconfig.yaml | cut -d ':' -f 2-3 | sed -e 's/ //'`
URL=https://images.maas.io/ephemeral-v2/daily/
KEYRING_FILE=/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg
SOURCE_ID=1
FABRIC_ID=1
VLAN_TAG=""
PRIMARY_RACK_CONTROLLER="$MAAS_IP"
SUBNET_CIDR=`cat labconfig.json | jq '.opnfv.spaces[] | select(.type=="admin")'.cidr | cut -d \" -f 2 `
VLAN_TAG="untagged"

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

echo "... Deployment of maas Started ...."

#
# Virsh preparation
#

# define the pool and try to start even though its already exist.
# For fresh install this may or may not there.
sudo adduser $USER libvirtd
sudo virsh pool-define-as default --type dir --target /var/lib/libvirt/images/ || true
sudo virsh pool-start default || true
sudo virsh pool-autostart default || true

# In case of virtual install set network
if [ "$virtinstall" -eq 1 ]; then
    sudo virsh net-dumpxml default > default-net-org.xml
    sudo sed -i '/dhcp/d' default-net-org.xml
    sudo sed -i '/range/d' default-net-org.xml
    sudo virsh net-define default-net-org.xml
    sudo virsh net-destroy default
    sudo virsh net-start default
    rm -f default-net-org.xml
fi

#
# Cleanup, juju init and config backup
#

# To avoid problem between apiclient/maas_client and apiclient from google
# we remove the package google-api-python-client from yardstick installer
if [ $(pip list |grep google-api-python-client |wc -l) == 1 ]; then
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
    sudo ./maas-reconfigure-region.sh $MAAS_IP
    sudo maas-rack config --region-url http://$MAAS_IP:5240/MAAS

    sudo maas createadmin --username=ubuntu --email=ubuntu@ubuntu.com --password=ubuntu || true
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY
    maas $PROFILE maas set-config name='main_archive' value=$MAIN_ARCHIVE || true
    maas $PROFILE maas set-config name=upstream_dns value=$MY_UPSTREAM_DNS || true
    maas $PROFILE maas set-config name='maas_name' value=$MAAS_NAME || true
    maas $PROFILE maas set-config name='ntp_server' value='ntp.ubuntu.com' || true
    maas $PROFILE sshkeys create "key=$SSH_KEY" || true

    maas $PROFILE tags create name='bootstrap' || true
    maas $PROFILE tags create name='compute' || true
    maas $PROFILE tags create name='control' || true
    maas $PROFILE tags create name='storage' || true

    #create the required spaces.
    maas $PROFILE space update 0 name=default || true
    maas $PROFILE spaces create name=unused || true
    maas $PROFILE spaces create name=admin-api || true
    maas $PROFILE spaces create name=internal-api || true
    maas $PROFILE spaces create name=public-api || true
    maas $PROFILE spaces create name=compute-data || true
    maas $PROFILE spaces create name=compute-external || true
    maas $PROFILE spaces create name=storage-data || true
    maas $PROFILE spaces create name=storage-cluster || true

    maas $PROFILE boot-source update $SOURCE_ID \
         url=$URL keyring_filename=$KEYRING_FILE || true

    maas $PROFILE boot-resources import || true
    sleep 10

    while [ "$(maas $PROFILE boot-resources is-importing)" == "true" ];
    do
        sleep 60
    done

    #maas $PROFILE subnet update vlan:<vlan id> name=internal-api space=<0> gateway_ip=10.5.1.1
    #maas $PROFILE subnet update vlan:<vlan id> name=admin-api space=<2> gateway_ip=10.5.12.1
    #maas $PROFILE subnet update vlan:<vlan id> name=public-api space=<1> gateway_ip=10.5.15.1
    #maas $PROFILE subnet update vlan:<vlan id> name=compute-data space=<3> gateway_ip=10.5.17.1
    #maas $PROFILE subnet update vlan:<vlan id> name=compute-external space=<4> gateway_ip=10.5.19.1
    #maas $PROFILE subnet update vlan:<vlan id> name=storage-data space=<5> gateway_ip=10.5.20.1
    #maas $PROFILE subnet update vlan:<vlan id> name=storage-cluster space=<6> gateway_ip=10.5.21.1

}

enablesubnetanddhcp(){
    SUBNET_PREFIX=${SUBNET_CIDR::-5}

    IP_RES_RANGE_LOW="$SUBNET_PREFIX.1"
    IP_RES_RANGE_HIGH="$SUBNET_PREFIX.39"

    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY

    maas $PROFILE ipranges create type=reserved \
         start_ip=$IP_RES_RANGE_LOW end_ip=$IP_RES_RANGE_HIGH \
         comment='This is a reserved range' || true

    IP_DYNAMIC_RANGE_LOW="$SUBNET_PREFIX.40"
    IP_DYNAMIC_RANGE_HIGH="$SUBNET_PREFIX.150"

    maas $PROFILE ipranges create type=dynamic \
        start_ip=$IP_DYNAMIC_RANGE_LOW end_ip=$IP_DYNAMIC_RANGE_HIGH \
        comment='This is a reserved dynamic range' || true


    FABRIC_ID=$(maas $PROFILE subnet read $SUBNET_CIDR | jq '.vlan.fabric_id')

    PRIMARY_RACK_CONTROLLER=$(maas $PROFILE rack-controllers read | jq -r '.[0].system_id')

    maas $PROFILE vlan update $FABRIC_ID $VLAN_TAG dhcp_on=True primary_rack=$PRIMARY_RACK_CONTROLLER || true

    MY_GATEWAY=`cat deployconfig.json | jq '.opnfv.admNetgway' | cut -d \" -f 2`
    MY_NAMESERVER=`cat deployconfig.json | jq '.opnfv.upstream_dns' | cut -d \" -f 2`
    maas $PROFILE subnet update $SUBNET_CIDR gateway_ip=$MY_GATEWAY || true
    maas $PROFILE subnet update $SUBNET_CIDR dns_servers=$MY_NAMESERVER || true

    #below command will enable the interface with internal-api space.

    SPACEID=$(maas $PROFILE space read internal-api | jq '.id')
    maas $PROFILE subnet update $SUBNET_CIDR space=$SPACEID || true

}

addnodes(){
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY

    # make sure there is no machine entry in maas
    for m in $(maas $PROFILE machines read | jq -r '.[].system_id')
    do
        maas ubuntu machine delete $m
    done

    if [ "$virtinstall" -eq 1 ]; then
        netw=" --network bridge=virbr0,model=virtio"
    else
        brid=`brctl show | grep 8000 | cut -d "8" -f 1 |  tr "\n" " " | tr "\t" " " | tr -s " "`

        netw=""
        for feature in $brid; do
            if [ "$feature" == "" ]; then
                netw=$netw
            elif [ "$feature" == "virbr0" ]; then
                netw=$netw
            else
                netw=$netw" --network bridge="$feature",model=virtio"
            fi
        done
    fi

    sudo virt-install --connect qemu:///system --name bootstrap --ram 4098 --cpu host --vcpus 2 --video \
                 cirrus --arch x86_64 --disk size=20,format=qcow2,bus=virtio,io=native,pool=default \
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
    sudo virsh -c qemu:///system define --file bootstrap
    rm -f bootstrap

    maas $PROFILE machines create autodetect_nodegroup='yes' name='bootstrap' \
        tags='bootstrap' hostname='bootstrap' power_type='virsh' mac_addresses=$bootstrapmac \
        power_parameters_power_address='qemu+ssh://'$USER'@'$MAAS_IP'/system' \
        architecture='amd64/generic' power_parameters_power_id='bootstrap'

    bootstrapid=$(maas $PROFILE machines read | jq -r 'select(.[].hostname == "bootstrap")[0].system_id')

    maas $PROFILE tag update-nodes bootstrap add=$bootstrapid

    if [ "$virtinstall" -eq 1 ]; then

        sudo virt-install --connect qemu:///system --name node1-control --ram 8192 --cpu host --vcpus 4 \
                     --disk size=120,format=qcow2,bus=virtio,io=native,pool=default \
                     $netw $netw --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node1-control

        sudo virt-install --connect qemu:///system --name node2-compute --ram 8192 --cpu host --vcpus 4 \
                    --disk size=120,format=qcow2,bus=virtio,io=native,pool=default \
                    $netw $netw --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node2-compute

        sudo virt-install --connect qemu:///system --name node5-compute --ram 8192 --cpu host --vcpus 4 \
                   --disk size=120,format=qcow2,bus=virtio,io=native,pool=default \
                   $netw $netw --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node5-compute


        node1controlmac=`grep  "mac address" node1-control | head -1 | cut -d '"' -f 2`
        node2computemac=`grep  "mac address" node2-compute | head -1 | cut -d '"' -f 2`
        node5computemac=`grep  "mac address" node5-compute | head -1 | cut -d '"' -f 2`

        sudo virsh -c qemu:///system define --file node1-control
        sudo virsh -c qemu:///system define --file node2-compute
        sudo virsh -c qemu:///system define --file node5-compute
        rm -f node1-control node2-compute node5-compute


        maas $PROFILE machines create autodetect_nodegroup='yes' name='node1-control' \
            tags='control' hostname='node1-control' power_type='virsh' mac_addresses=$node1controlmac \
            power_parameters_power_address='qemu+ssh://'$USER'@'$MAAS_IP'/system' \
            architecture='amd64/generic' power_parameters_power_id='node1-control'
        controlnodeid=$(maas $PROFILE machines read | jq -r 'select(.[].hostname == "node1-control")[0].system_id')
        maas $PROFILE machines create autodetect_nodegroup='yes' name='node2-compute' \
            tags='compute' hostname='node2-compute' power_type='virsh' mac_addresses=$node2computemac \
            power_parameters_power_address='qemu+ssh://'$USER'@'$MAAS_IP'/system' \
            architecture='amd64/generic' power_parameters_power_id='node2-compute'
        compute2nodeid=$(maas $PROFILE machines read | jq -r 'select(.[].hostname == "node2-compute")[0].system_id')
        maas $PROFILE machines create autodetect_nodegroup='yes' name='node5-compute' \
            tags='compute' hostname='node5-compute' power_type='virsh' mac_addresses=$node5computemac \
            power_parameters_power_address='qemu+ssh://'$USER'@'$MAAS_IP'/system' \
            architecture='amd64/generic' power_parameters_power_id='node5-compute'
        compute5nodeid=$(maas $PROFILE machines read | jq -r 'select(.[].hostname == "node5-compute")[0].system_id')

        maas $PROFILE tag update-nodes control add=$controlnodeid || true
        maas $PROFILE tag update-nodes compute add=$compute2nodeid || true
        maas $PROFILE tag update-nodes compute add=$compute5nodeid || true
    else
       units=`cat deployconfig.json | jq .opnfv.units`

       until [ $(($units)) -lt 1 ]; do
           units=$(($units - 1));
           NODE_NAME=`cat labconfig.json | jq ".lab.racks[].nodes[i].name" | cut -d \" -f 2 `
           MAC_ADDRESS=`cat labconfig.json | jq ".lab.racks[].nodes[i].nics[] | select(.spaces[]==\"admin\").mac"[0] | cut -d \" -f 2 `
           POWER_TYPE=`cat labconfig.json | jq ".lab.racks[].nodes[i].power.type" | cut -d \" -f 2 `
           POWER_IP=`cat labconfig.json |  jq ".lab.racks[].nodes[i].power.address" | cut -d \" -f 2 `
           POWER_USER=`cat labconfig.json |  jq ".lab.racks[].nodes[i].power.user" | cut -d \" -f 2 `
           POWER_PASS=`cat labconfig.json |  jq ".lab.racks[].nodes[i].power.pass" | cut -d \" -f 2 `

           maas $PROFILE machines create autodetect_nodegroup='yes' name=$NODE_NAME \
               hostname=$NODE_NAME power_type=$POWER_TYPE power_parameters_power_address=$POWER_IP \
               power_parameters_power_user=$POWER_USER power_parameters_power_pass=$POWER_PASS mac_addresses=$MAC_ADDRESS \
               architecture='amd64/generic'
       done
    fi

    # make sure nodes are added into MAAS and none of them is in commisoning state
    while [ "$(maas $PROFILE nodes read | grep  Commissioning )" ];
    do
        sleep 60
    done

}

#configure MAAS with the different options.
configuremaas

#not virtual lab only. Can be done using any physical pod now.
enablesubnetanddhcp

#just make sure rack controller has been synced and import only
# just whether images have been imported or not.
sleep 120

#lets add the nodes now. Currently works only for virtual deploymnet.
addnodes

echo "... Deployment of maas finish ...."

#Added the Qtip public to run the Qtip test after install on bare metal nodes.
#maas $PROFILE sshkeys new key="`cat ./maas/sshkeys/QtipKey.pub`"
#maas $PROFILE sshkeys new key="`cat ./maas/sshkeys/DominoKey.pub`"

#
# Functions for MAAS network customization
#

#Below function will mark the interfaces in Auto mode to enbled by MAAS
enableautomode() {
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY

    for node in $(maas $PROFILE nodes read | jq -r '.[].system_id')
    do
        maas $PROFILE interface link-subnet $node $1  mode=$2 subnet=$3 || true
    done
}

#Below function will mark the interfaces in Auto mode to enbled by MAAS
# using hostname of the node added into MAAS
enableautomodebyname() {
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY

    if [ ! -z "$4" ]; then
        for i in `seq 1 7`;
        do
            nodes=$(maas $PROFILE nodes read | jq -r '.[].system_id')
            if [ ! -z "$nodes" ]; then
                maas $PROFILE interface link-subnet $nodes $1  mode=$2 subnet=$3 || true
            fi
       done
    fi
}

#Below function will create vlan and update interface with the new vlan
# will return the vlan id created
crvlanupdsubnet() {
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY

    # TODO: fix subnet creation and use 'jq'
    newvlanid=`maas $PROFILE vlans create $2 name=$3 vid=$4 | grep resource | cut -d '/' -f 6 `
    maas $PROFILE subnet update $5 vlan=$newvlanid
    eval "$1"="'$newvlanid'"
}

#Below function will create interface with new vlan and bind to physical interface
crnodevlanint() {
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVERMAAS $API_KEY

    for node in $(maas $PROFILE nodes read | jq -r '.[].system_id')
    do
        interface=$(maas $PROFILE interface read $node $2 | jq -r '.id')
        maas $PROFILE interfaces create-vlan $node vlan=$1 parent=$interface
     done
 }

#function for JUJU envronment

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

    juju add-cloud $cloudname maas-cloud.yaml --replace
}


#
# VLAN customization
#

case "$labname" in
    'intelpod9' )
        maas refresh
        crvlanupdsubnet vlan904 fabric-1 "MgmtNetwork" 904 2 || true
        crvlanupdsubnet vlan905 fabric-2 "PublicNetwork" 905 3 || true
        crnodevlanint $vlan905 eth1 || true
        crnodevlanint $vlan905 eth3 || true
        enableautomodebyname eth1.905 AUTO "10.9.15.0/24" || true
        enableautomodebyname eth3.905 AUTO "10.9.15.0/24" || true
        enableautomodebyname eth0 AUTO "10.9.12.0/24" || true
        enableautomodebyname eth2 AUTO "10.9.12.0/24" || true
        ;;
esac

#
# Enable MAAS nodes interfaces
#

#read interface needed in Auto mode and enable it. Will be rmeoved once auto enablement will be implemented in the maas-deployer.

if [ -e ./deployconfig.yaml ]; then
  enableiflist=`grep "interface-enable" deployconfig.yaml | cut -d ' ' -f 4 `
  datanet=`grep "dataNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
  stornet=`grep "storageNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
  pubnet=`grep "publicNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`

  # split EXTERNAL_NETWORK=first ip;last ip; gateway;network

  if [ "$datanet" != "''" ]; then
      EXTNET=(${enableiflist//,/ })
      i="0"
      while [ ! -z "${EXTNET[i]}" ];
      do
          enableautomode ${EXTNET[i]} AUTO $datanet || true
          i=$[$i+1]
      done

  fi
  if [ "$stornet" != "''" ]; then
      EXTNET=(${enableiflist//,/ })
      i="0"
      while [ ! -z "${EXTNET[i]}" ];
      do
          enableautomode ${EXTNET[i]} AUTO $stornet || true
          i=$[$i+1]
      done
  fi
  if [ "$pubnet" != "''" ]; then
      EXTNET=(${enableiflist//,/ })
      i="0"
      while [ ! -z "${EXTNET[i]}" ];
      do
          enableautomode ${EXTNET[i]} AUTO $pubnet || true
          i=$[$i+1]
      done
  fi
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
echo " .... MAAS deployment finished successfully ...."
