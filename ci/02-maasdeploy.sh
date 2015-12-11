#!/bin/bash
#placeholder for deployment script.
set -ex

virtinstall=0

case "$1" in
    'intelpod5' )
        cp maas/intel/pod5/deployment.yaml ./deployment.yaml
        ;;
    'intelpod6' )
        cp maas/intel/pod6/deployment.yaml ./deployment.yaml
        ;;
    'orangepod2' )
        cp maas/orange/pod2/deployment.yaml ./deployment.yaml
        ;;
    'attvirpod1' )
        cp maas/att/virpod1/deployment.yaml ./deployment.yaml
        ;;
    'juniperpod1' )
        cp maas/juniper/pod1/deployment.yaml ./deployment.yaml
        ;;
    * )
        virtinstall=1
        cp maas/default/deployment.yaml ./deployment.yaml
        ;;
esac

echo "... Deployment of maas Started ...."

if [ ! -e $HOME/.ssh/id_rsa ]; then
    ssh-keygen -N '' -f $HOME/.ssh/id_rsa
fi

if [ ! -e /var/lib/libvirt/images ]; then

    sudo apt-get install libvirt-bin -y
    sudo adduser ubuntu libvirtd
    sudo virsh pool-define-as default --type dir --target /var/lib/libvirt/images/
    sudo virsh pool-start default
    sudo virsh pool-autostart default

fi

sudo apt-add-repository ppa:maas-deployers/stable -y
sudo apt-add-repository ppa:juju/stable -y
sudo apt-add-repository ppa:maas/stable -y
sudo apt-get update -y
sudo apt-get install openssh-server git maas-deployer juju juju-deployer maas-cli -y
juju init -f

cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys

if [ $virtinstall ]; then
    sudo virsh net-dumpxml default > default-net-org.xml
    sudo sed -i '/dhcp/d' default-net-org.xml
    sudo sed -i '/range/d' default-net-org.xml
    sudo virsh net-define default-net-org.xml
    sudo virsh net-destroy default
    sudo virsh net-start default
fi

sudo maas-deployer -c deployment.yaml -d --force

sudo chown $USER:$USER environments.yaml

echo "... Deployment of maas finish ...."

maas_ip=`grep " ip_address" deployment.yaml | cut -d " "  -f 10`
apikey=`grep maas-oauth: environments.yaml | cut -d "'" -f 2`
maas login maas http://${maas_ip}/MAAS/api/1.0 ${apikey}
maas maas boot-source update 1 url="http://maas.ubuntu.com/images/ephemeral-v2/daily/"
#maas maas boot-source-selections create 1 os="ubuntu" release="precise" arches="amd64" subarches="*" labels="*"
maas maas boot-resources import
maas maas sshkeys new key="`cat $HOME/.ssh/id_rsa.pub`"

#adding compute and control nodes VM to MAAS for deployment purpose.
if [ $virtinstall ]; then
    # create two more VMs to do the deployment.
    sudo virt-install --connect qemu:///system --name node1-control --ram 8192 --vcpus 4 --disk size=120,format=qcow2,bus=virtio,io=native,pool=default --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node1-control

    sudo virt-install --connect qemu:///system --name node2-compute --ram 8192 --vcpus 4 --disk size=120,format=qcow2,bus=virtio,io=native,pool=default --network bridge=virbr0,model=virtio --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee node2-compute

    node1controlmac=`grep  "mac address" node1-control | cut -d "'" -f 2`
    node2computemac=`grep  "mac address" node2-compute | cut -d "'" -f 2`

    sudo virsh -c qemu:///system define --file node1-control
    sudo virsh -c qemu:///system define --file node2-compute

    maas maas tags new name='control'
    maas maas tags new name='compute'

    controlnodeid=`maas maas nodes new autodetect_nodegroup='yes' name='node1-control' tags='control' hostname='node1-control' power_type='virsh' mac_addresses=$node1controlmac power_parameters_power_address='qemu+ssh://ubuntu@192.168.122.1/system' architecture='amd64/generic' power_parameters_power_id='node1-control' | grep system_id | cut -d '"' -f 4 `

    maas maas tag update-nodes control add=$controlnodeid

    computenodeid=`maas maas nodes new autodetect_nodegroup='yes' name='node2-compute' tags='compute' hostname='node2-compute' power_type='virsh' mac_addresses=$node2computemac power_parameters_power_address='qemu+ssh://ubuntu@192.168.122.1/system' architecture='amd64/generic' power_parameters_power_id='node2-compute' | grep system_id | cut -d '"' -f 4 `

    maas maas tag update-nodes compute add=$computenodeid

fi

#echo "... Deployment of opnfv release Started ...."
#python deploy.py $maas_ip

