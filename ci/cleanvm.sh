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
sudo rm -rf  /var/lib/libvirt/images/node1-control.img /var/lib/libvirt/images/node2-compute.img /var/lib/libvirt/images/node3-control.img /var/lib/libvirt/images/node4-control.img /var/lib/libvirt/images/node5-compute.img || true
 
if [[ "$maasver" > "2" ]]; then
    sudo virsh destroy bootstrap || true
    sudo virsh undefine bootstrap || true
    sudo rm -rf  /var/lib/libvirt/images/bootstrap.img || true
fi

echo " Cleanup Finished ..."
