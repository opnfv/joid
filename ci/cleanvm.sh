#!/bin/bash

set -x

echo " Cleanup Started ..."

#use the below commands if you needs to delete the virtual machine
# also along with environment destroy.
./clean.sh

vm_list=$(sudo virsh list --all)

for vm in node1-control node2-compute node3-control node4-control \
          node5-compute rack-vir-m1 rack-vir-m2 rack-vir-m3 rack-vir-m4 \
          rack-vir-m1 bootstrap
do
    echo "$vm_list" | grep -q " $vm " || continue
    sudo virsh destroy $vm
    sudo virsh undefine $vm
    sudo rm -f /var/lib/libvirt/images/${vm}.qcow2
done

echo " Cleanup Finished ..."
