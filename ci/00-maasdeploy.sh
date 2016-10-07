#!/bin/bash
#placeholder for deployment script.
set -ex

virtinstall=0
labname=$1

#install the packages needed
sudo apt-add-repository ppa:opnfv-team/proposed -y
sudo apt-add-repository ppa:maas-deployers/stable -y
sudo apt-add-repository ppa:juju/stable -y
sudo apt-add-repository ppa:maas/stable -y
sudo apt-add-repository cloud-archive:mitaka -y
sudo apt-get update -y
sudo apt-get dist-upgrade -y
sudo apt-get install openssh-server bzr git maas-deployer juju juju-deployer \
             maas-cli python-pip python-psutil python-openstackclient \
             python-congressclient gsutil charm-tools pastebinit -y

#first parameter should be custom and second should be either
# absolute location of file (including file name) or url of the
# file to download.

labname=$1
labfile=$2

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

# In the case of a virtual deployment get deployment.yaml and deployconfig.yaml
if [ "$virtinstall" -eq 1 ]; then
    labname="default"
    ./cleanvm.sh
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

if [ ! -e $HOME/.ssh/id_rsa ]; then
    ssh-keygen -N '' -f $HOME/.ssh/id_rsa
fi

echo "... Deployment of maas Started ...."

#
# Virsh preparation
#

# define the pool and try to start even though its already exist.
# For fresh install this may or may not there.
sudo apt-get install libvirt-bin -y
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

# Ensure virsh can connect without ssh auth
cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys


#
# Cleanup, juju init and config backup
#

# To avoid problem between apiclient/maas_client and apiclient from google
# we remove the package google-api-python-client from yardstick installer
if [ $(pip list |grep google-api-python-client |wc -l) == 1 ]; then
    sudo pip uninstall google-api-python-client
fi

# Init Juju
juju init -f

#
# MAAS deploy
#

sudo maas-deployer -c deployment.yaml -d --force

sudo chown $USER:$USER environments.yaml

echo "... Deployment of maas finish ...."

# Backup deployment.yaml and deployconfig.yaml in .juju folder

cp ./environments.yaml ~/.juju/

if [ -e ./deployconfig.yaml ]; then
    cp ./deployconfig.yaml ~/.juju/
    cp ./labconfig.yaml ~/.juju/
fi

if [ -e ./deployment.yaml ]; then
    cp ./deployment.yaml ~/.juju/
fi

#
# MAAS Customization
#

maas_ip=`grep " ip_address" deployment.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
apikey=`grep maas-oauth: environments.yaml | cut -d "'" -f 2`
maas login maas http://${maas_ip}/MAAS/api/1.0 ${apikey}
maas maas sshkeys new key="`cat $HOME/.ssh/id_rsa.pub`"

#Added the Qtip public to run the Qtip test after install on bare metal nodes.
#maas maas sshkeys new key="`cat ./maas/sshkeys/QtipKey.pub`"
#maas maas sshkeys new key="`cat ./maas/sshkeys/DominoKey.pub`"

#adding compute and control nodes VM to MAAS for virtual deployment purpose.
if [ "$virtinstall" -eq 1 ]; then
    # create two more VMs to do the deployment.
    sudo virt-install --connect qemu:///system --name node1-control --ram 8192 --vcpus 4 --disk size=120,format=qcow2,bus=virtio,io=native,pool=default --network bridge=virbr0,model=virtio --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node1-control

    sudo virt-install --connect qemu:///system --name node2-compute --ram 8192 --vcpus 4 --disk size=120,format=qcow2,bus=virtio,io=native,pool=default --network bridge=virbr0,model=virtio --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node2-compute

    sudo virt-install --connect qemu:///system --name node5-compute --ram 8192 --vcpus 4 --disk size=120,format=qcow2,bus=virtio,io=native,pool=default --network bridge=virbr0,model=virtio --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node5-compute

    node1controlmac=`grep  "mac address" node1-control | head -1 | cut -d "'" -f 2`
    node2computemac=`grep  "mac address" node2-compute | head -1 | cut -d "'" -f 2`
    node5computemac=`grep  "mac address" node5-compute | head -1 | cut -d "'" -f 2`

    sudo virsh -c qemu:///system define --file node1-control
    sudo virsh -c qemu:///system define --file node2-compute
    sudo virsh -c qemu:///system define --file node5-compute

    maas maas tags new name='control'
    maas maas tags new name='compute'

    controlnodeid=`maas maas nodes new autodetect_nodegroup='yes' name='node1-control' tags='control' hostname='node1-control' power_type='virsh' mac_addresses=$node1controlmac power_parameters_power_address='qemu+ssh://'$USER'@192.168.122.1/system' architecture='amd64/generic' power_parameters_power_id='node1-control' | grep system_id | cut -d '"' -f 4 `

    maas maas tag update-nodes control add=$controlnodeid

    computenodeid=`maas maas nodes new autodetect_nodegroup='yes' name='node2-compute' tags='compute' hostname='node2-compute' power_type='virsh' mac_addresses=$node2computemac power_parameters_power_address='qemu+ssh://'$USER'@192.168.122.1/system' architecture='amd64/generic' power_parameters_power_id='node2-compute' | grep system_id | cut -d '"' -f 4 `

    maas maas tag update-nodes compute add=$computenodeid

    computenodeid=`maas maas nodes new autodetect_nodegroup='yes' name='node5-compute' tags='compute' hostname='node5-compute' power_type='virsh' mac_addresses=$node5computemac power_parameters_power_address='qemu+ssh://'$USER'@192.168.122.1/system' architecture='amd64/generic' power_parameters_power_id='node5-compute' | grep system_id | cut -d '"' -f 4 `

    maas maas tag update-nodes compute add=$computenodeid
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
if [ -e ~/.juju/deployconfig.yaml ]; then
  cp ~/.juju/deployconfig.yaml ./deployconfig.yaml

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

#
# End of scripts
#
echo " .... MAAS deployment finished successfully ...."
