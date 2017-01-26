#!/bin/bash

set -ex

#use the below commands if you needs to delete the virtual machine
# also along with envuronment destroy.

echo " Cleanup Started ..."
./clean.sh || true
 
maasver=`apt-cache policy maas | grep Installed | cut -d ':' -f 2 | sed -e 's/ //'`

sudo virsh destroy node1-control || true
sudo virsh destroy node3-control || true
sudo virsh destroy node4-control || true
sudo virsh destroy node2-compute || true
sudo virsh destroy node5-compute || true
sudo virsh undefine node1-control || true
sudo virsh undefine node3-control || true
sudo virsh undefine node4-control || true
sudo virsh undefine node2-compute || true
sudo virsh undefine node5-compute || true
sudo rm -rf  /var/lib/libvirt/images/node1-control.qcow2 /var/lib/libvirt/images/node2-compute.qcow2 /var/lib/libvirt/images/node3-control.qcow2 /var/lib/libvirt/images/node4-control.qcow2 /var/lib/libvirt/images/node5-compute.qcow2 || true
 
if [[ "$maasver" > "2" ]]; then
    sudo virsh destroy bootstrap || true
    sudo virsh undefine bootstrap || true
    sudo rm -rf  /var/lib/libvirt/images/bootstrap.qcow2 || true
fi

echo " Cleanup Finished ..."
