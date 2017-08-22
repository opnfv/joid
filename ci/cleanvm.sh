#!/bin/bash

set -x

source common/tools.sh

echo_info "Cleanup Started..."

vm_list=$(sudo virsh list --all)

for vm in node1-control node2-compute node3-control node4-control \
          node5-compute rack-vir-m1 rack-vir-m2 rack-vir-m3 rack-vir-m4 \
          rack-vir-m1 bootstrap
do
    echo "$vm_list" | grep -q " $vm " || continue
    sudo virsh destroy $vm
    sudo virsh undefine --nvram $vm
    sudo rm -f /var/lib/libvirt/images/${vm}.qcow2
done

echo_info "Cleanup Finished!"
