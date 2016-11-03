#!/bin/bash
#placeholder for deployment script.
set -ex

maasver=`apt-cache policy maas | grep Installed | cut -d ':' -f 2 | sed -e 's/ //'`

if [[ "$maasver" > "2" ]]; then
    echo "removing existing maas ..."
    #sudo apt-get purge maas maas-cli maas-common maas-dhcp maas-dns maas-proxy maas-rack-controller maas-region-api maas-region-controller  -y
    #sudo rm -rf /var/lib/maas
fi

virtinstall=0
labname=$1

if [ ! -e $HOME/.ssh/id_rsa ]; then
    ssh-keygen -N '' -f $HOME/.ssh/id_rsa
fi

#install the packages needed
sudo apt-add-repository ppa:juju/stable -y
sudo apt-add-repository ppa:maas/stable -y
sudo apt-add-repository cloud-archive:newton -y
sudo apt-get update -y
sudo apt-get dist-upgrade -y
sudo apt-get install openssh-server bzr git juju virtinst qemu-kvm libvirt-bin \
             maas maas-region-controller python-pip python-psutil python-openstackclient \
             python-congressclient gsutil charm-tools pastebinit python-jinja2 -y

sudo pip install --upgrade pip

#first parameter should be custom and second should be either
# absolute location of file (including file name) or url of the
# file to download.


#
# Config preparation
#

# Get labconfig and generate deployment.yaml for MAAS and deployconfig.yaml
case "$labname" in
    intelpod[569]|orangepod[12]|cengnpod[12] )
        array=(${labname//pod/ })
        cp ../labconfig/${array[0]}/pod${array[1]}/labconfig.yaml .
        python genMAASConfig.py -l labconfig.yaml > deployment.yaml
        python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
        ;;
    'attvirpod1' )
        cp ../labconfig/att/virpod1/labconfig.yaml .
        python genMAASConfig.py -l labconfig.yaml > deployment.yaml
        python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
        ;;
    'juniperpod1' )
        cp maas/juniper/pod1/deployment.yaml ./deployment.yaml
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
        else
            python genMAASConfig.py -l labconfig.yaml > deployment.yaml
            python genDeploymentConfig.py -l labconfig.yaml > deployconfig.yaml
            labname=`grep "maas_name" deployment.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
        fi
        ;;
    * )
        virtinstall=1
        ;;
esac

MAAS_IP=$(grep " ip_address" deployment.yaml | cut -d ':' -f 2 | sed -e 's/ //')
MAAS_NAME=`grep "maas_name" deployment.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
API_SERVER="http://$MAAS_IP/MAAS/api/2.0"
API_SERVERMAAS="http://$MAAS_IP/MAAS/"
PROFILE=ubuntu
MY_UPSTREAM_DNS=`grep "upstream_dns" deployment.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
SSH_KEY=`cat ~/.ssh/id_rsa.pub`
MAIN_ARCHIVE=`grep "main_archive" deployment.yaml | cut -d ':' -f 2-3 | sed -e 's/ //'`
URL=https://images.maas.io/ephemeral-v2/daily/
KEYRING_FILE=/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg
SOURCE_ID=1
FABRIC_ID=1
VLAN_TAG=""
PRIMARY_RACK_CONTROLLER="$MAAS_IP"
SUBNET_CIDR="192.168.122.0/24"
VLAN_TAG="untagged"

# In the case of a virtual deployment get deployment.yaml and deployconfig.yaml
if [ "$virtinstall" -eq 1 ]; then
    labname="default"
    MAAS_IP="192.168.122.1"
    API_SERVER="http://$MAAS_IP/MAAS/api/2.0"
    API_SERVERMAAS="http://$MAAS_IP/MAAS/"
    PRIMARY_RACK_CONTROLLER="$MAAS_IP"
    ./cleanvm.sh || true
    cp ../labconfig/default/deployment.yaml ./
    cp ../labconfig/default/labconfig.yaml ./
    cp ../labconfig/default/deployconfig.yaml ./
fi

#
# Prepare local environment to avoid password asking
#

# make sure no password asked during the deployment.
echo "$USER ALL=(ALL) NOPASSWD:ALL" > 90-joid-init

if [ -e /etc/sudoers.d/90-joid-init ]; then
    sudo cp /etc/sudoers.d/90-joid-init 91-joid-init
    sudo chown $USER:$USER 91-joid-init
    sudo chmod 660 91-joid-init
    sudo cat 90-joid-init >> 91-joid-init
    sudo chown root:root 91-joid-init
    sudo mv 91-joid-init /etc/sudoers.d/
else
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
fi

#
# Cleanup, juju init and config backup
#

# To avoid problem between apiclient/maas_client and apiclient from google
# we remove the package google-api-python-client from yardstick installer
if [ $(pip list |grep google-api-python-client |wc -l) == 1 ]; then
    sudo pip uninstall google-api-python-client
fi

#create backup directory
mkdir ~/joid_config/ || true
mkdir ~/.juju/ || true

sudo mkdir -p ~maas || true
sudo chown maas:maas ~maas
if [ ! -e ~maas/.ssh/id_rsa ]; then
    sudo -u maas ssh-keygen -N '' -f ~maas/.ssh/id_rsa -y
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
#
configuremaas(){
    sudo maas createadmin --username=ubuntu --email=ubuntu@ubuntu.com --password=ubuntu
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    maas login $PROFILE $API_SERVER $API_KEY
    maas $PROFILE maas set-config name='main_archive' value=$MAIN_ARCHIVE
    maas $PROFILE maas set-config name=upstream_dns value=$MY_UPSTREAM_DNS
    maas $PROFILE maas set-config name='maas_name' value=$MAAS_NAME
    maas $PROFILE maas set-config name='ntp_server' value='ntp.ubuntu.com'
    maas $PROFILE sshkeys create "key=$SSH_KEY"
    maas $PROFILE boot-source update $SOURCE_ID \
         url=$URL keyring_filename=$KEYRING_FILE
    maas $PROFILE boot-source-selections create 1 \
         release='trusty' arches='amd64' labels='daily' \
         os='ubuntu' subarches='*'
    maas $PROFILE boot-resources import

    while [ "$(maas $PROFILE boot-resources read | grep trusty | wc -l )" -le 0 ];
    do
        maas $PROFILE boot-resources import
        sleep 20
    done

    IP_STATIC_RANGE_LOW="192.168.122.1"
    IP_STATIC_RANGE_HIGH="192.168.122.49"
    maas $PROFILE ipranges create type=reserved \
         start_ip=$IP_STATIC_RANGE_LOW end_ip=$IP_STATIC_RANGE_HIGH \
         comment='This is a reserved range'

    IP_DYNAMIC_RANGE_LOW="192.168.122.50"
    IP_DYNAMIC_RANGE_HIGH="192.168.122.80"
    maas $PROFILE ipranges create type=dynamic \
        start_ip=$IP_DYNAMIC_RANGE_LOW end_ip=$IP_DYNAMIC_RANGE_HIGH \
        comment='This is a reserved dynamic range'

    FABRIC_ID=$(maas $PROFILE subnet read $SUBNET_CIDR \
                | grep fabric | cut -d ' ' -f 10 | cut -d '"' -f 2)

    PRIMARY_RACK_CONTROLLER=`maas $PROFILE rack-controllers read  | grep system_id | cut -d '"' -f 4`

    maas $PROFILE vlan update $FABRIC_ID $VLAN_TAG dhcp_on=True primary_rack=$PRIMARY_RACK_CONTROLLER

    SUBNET_CIDR="192.168.122.0/24"
    MY_GATEWAY="192.168.122.1"
    MY_NAMESERVER=192.168.122.1
    maas $PROFILE subnet update $SUBNET_CIDR gateway_ip=$MY_GATEWAY
    maas $PROFILE subnet update $SUBNET_CIDR dns_servers=$MY_NAMESERVER

    maas $PROFILE tags create name='bootstrap'
    maas $PROFILE tags create name='compute'
    maas $PROFILE tags create name='control'
    maas $PROFILE tags create name='storage'
}

addnodes(){
    sudo virt-install --connect qemu:///system --name bootstrap --ram 2048 --vcpus 2 --video \
                 cirrus --arch x86_64 --disk size=20,format=qcow2,bus=virtio,io=native,pool=default \
                 --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole \
                 --vnc --print-xml | tee bootstrap

    bootstrapmac=`grep  "mac address" bootstrap | head -1 | cut -d '"' -f 2`

    sudo virsh -c qemu:///system define --file bootstrap

    bootstrapid=`maas $PROFILE machines create autodetect_nodegroup='yes' name='bootstrap' \
                 tags='bootstrap' hostname='bootstrap' power_type='virsh' mac_addresses=$bootstrapmac \
                 power_parameters_power_address='qemu+ssh://'$USER'@192.168.122.1/system' \
                 architecture='amd64/generic' power_parameters_power_id='bootstrap' | grep system_id | cut -d '"' -f 4 `

    maas $PROFILE tag update-nodes bootstrap add=$bootstrapid
}

configuremaas
addnodes
#sudo chown $USER:$USER environments.yaml

echo "... Deployment of maas finish ...."

# Backup deployment.yaml and deployconfig.yaml in .juju folder

#cp ./environments.yaml ~/.juju/
#cp ./environments.yaml ~/joid_config/

if [ -e ./deployconfig.yaml ]; then
    cp ./deployconfig.yaml ~/.juju/
    cp ./labconfig.yaml ~/.juju/
    cp ./deployconfig.yaml ~/joid_config/
    cp ./labconfig.yaml ~/joid_config/
fi

if [ -e ./deployment.yaml ]; then
    cp ./deployment.yaml ~/.juju/
    cp ./deployment.yaml ~/joid_config/
fi

#Added the Qtip public to run the Qtip test after install on bare metal nodes.
#maas $PROFILE sshkeys new key="`cat ./maas/sshkeys/QtipKey.pub`"
#maas $PROFILE sshkeys new key="`cat ./maas/sshkeys/DominoKey.pub`"

#adding compute and control nodes VM to MAAS for virtual deployment purpose.
if [ "$virtinstall" -eq 1 ]; then
    # create two more VMs to do the deployment.
    sudo virt-install --connect qemu:///system --name node1-control --ram 8192 --vcpus 4 --disk size=120,format=qcow2,bus=virtio,io=native,pool=default --network bridge=virbr0,model=virtio --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node1-control

    sudo virt-install --connect qemu:///system --name node2-compute --ram 8192 --vcpus 4 --disk size=120,format=qcow2,bus=virtio,io=native,pool=default --network bridge=virbr0,model=virtio --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node2-compute

    sudo virt-install --connect qemu:///system --name node5-compute --ram 8192 --vcpus 4 --disk size=120,format=qcow2,bus=virtio,io=native,pool=default --network bridge=virbr0,model=virtio --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node5-compute

    node1controlmac=`grep  "mac address" node1-control | head -1 | cut -d '"' -f 2`
    node2computemac=`grep  "mac address" node2-compute | head -1 | cut -d '"' -f 2`
    node5computemac=`grep  "mac address" node5-compute | head -1 | cut -d '"' -f 2`

    sudo virsh -c qemu:///system define --file node1-control
    sudo virsh -c qemu:///system define --file node2-compute
    sudo virsh -c qemu:///system define --file node5-compute

    controlnodeid=`maas $PROFILE machines create autodetect_nodegroup='yes' name='node1-control' tags='control' hostname='node1-control' power_type='virsh' mac_addresses=$node1controlmac power_parameters_power_address='qemu+ssh://'$USER'@192.168.122.1/system' architecture='amd64/generic' power_parameters_power_id='node1-control' | grep system_id | cut -d '"' -f 4 `

    maas $PROFILE tag update-nodes control add=$controlnodeid

    computenodeid=`maas $PROFILE machines create autodetect_nodegroup='yes' name='node2-compute' tags='compute' hostname='node2-compute' power_type='virsh' mac_addresses=$node2computemac power_parameters_power_address='qemu+ssh://'$USER'@192.168.122.1/system' architecture='amd64/generic' power_parameters_power_id='node2-compute' | grep system_id | cut -d '"' -f 4 `

    maas $PROFILE tag update-nodes compute add=$computenodeid

    computenodeid=`maas $PROFILE machines create autodetect_nodegroup='yes' name='node5-compute' tags='compute' hostname='node5-compute' power_type='virsh' mac_addresses=$node5computemac power_parameters_power_address='qemu+ssh://'$USER'@192.168.122.1/system' architecture='amd64/generic' power_parameters_power_id='node5-compute' | grep system_id | cut -d '"' -f 4 `

    maas $PROFILE tag update-nodes compute add=$computenodeid
fi

#
# Functions for MAAS network customization
#

#Below function will mark the interfaces in Auto mode to enbled by MAAS
enableautomode() {
    listofnodes=`maas maas nodes list | grep system_id | cut -d '"' -f 4`
    for nodes in $listofnodes
    do
        maas maas interface link-subnet $nodes $1  mode=$2 subnet=$3
    done
}

#Below function will mark the interfaces in Auto mode to enbled by MAAS
# using hostname of the node added into MAAS
enableautomodebyname() {
    if [ ! -z "$4" ]; then
        for i in `seq 1 7`;
        do
            nodes=`maas maas nodes list | grep system_id | cut -d '"' -f 4`
            if [ ! -z "$nodes" ]; then
                maas maas interface link-subnet $nodes $1  mode=$2 subnet=$3
            fi
       done
    fi
}

#Below function will create vlan and update interface with the new vlan
# will return the vlan id created
crvlanupdsubnet() {
    newvlanid=`maas maas vlans create $2 name=$3 vid=$4 | grep resource | cut -d '/' -f 6 `
    maas maas subnet update $5 vlan=$newvlanid
    eval "$1"="'$newvlanid'"
}

#Below function will create interface with new vlan and bind to physical interface
crnodevlanint() {
    listofnodes=`maas maas nodes list | grep system_id | cut -d '"' -f 4`

    for nodes in $listofnodes
    do
        parentid=`maas maas interface read $nodes $2 | grep interfaces | cut -d '/' -f 8`
        maas maas interfaces create-vlan $nodes vlan=$1 parent=$parentid
     done
 }

#function for JUJU envronment

addcredential() {
    API_KEY=`sudo maas-region apikey --username=ubuntu`
    controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployment.yaml`
    cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployment.yaml`

    echo  "credentials:" > credential.yaml
    echo  "  $controllername:" >> credential.yaml
    echo  "    opnfv-credentials:" >> credential.yaml
    echo  "      auth-type: oauth1" >> credential.yaml
    echo  "      maas-oauth: $API_KEY" >> credential.yaml

    juju add-credential $controllername -f credential.yaml --replace
}

addcloud() {
    controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployment.yaml`
    cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployment.yaml`

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
if [ -e ~/joid_config/deployconfig.yaml ]; then
  cp ~/joid_config/deployconfig.yaml ./deployconfig.yaml
elif [ -e ~/.juju/deployconfig.yaml ]; then
  cp ~/.juju/deployconfig.yaml ./deployconfig.yaml
fi

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

if [ "$jujuver" > "2" ]; then
    addcloud
    addcredential
fi

#
# End of scripts
#
echo " .... MAAS deployment finished successfully ...."
