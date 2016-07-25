#!/bin/bash -ex

. ./cloud/admin-openrc

##enable extra stuff only if testing manually

neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default

wget -P /tmp/images http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
openstack image create --file /tmp/images/cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare "cirros-0.3.4-x86_64"
wget -P /tmp/images http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
openstack image create --file /tmp/images/trusty-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare "ubuntu-trusty-daily"
#wget -P /tmp/images http://cloud-images.ubuntu.com/trusty/current/xenial-server-cloudimg-amd64.tar.gz
#openstack image create --file /tmp/images/xenial-server-cloudimg-amd64.tar.gz --container-format bare --disk-format raw "xenial-server-cloudimg-amd64"

rm -rf /tmp/images

## import key pair
openstack project create --description "Demo Tenant" demo
openstack user create --project demo --password demo --email demo@demo.demo demo

openstack keypair create --public-key ~/.ssh/id_rsa.pub ubuntu-keypair

## create vm network
neutron net-create demo-net
neutron subnet-create demo-net 10.20.5.0/24 --name demo-subnet --gateway 10.20.5.1 --enable-dhcp --allocation-pool start=10.20.0.5,end=10.20.0.254 --dns-nameserver 8.8.8.8
neutron router-create demo-router
neutron router-gateway-set demo-router ext-net
neutron router-interface-add demo-router subnet=demo-subnet

# add a delay since the previous command takes the neutron-api offline for a while (?)
sleep 30

## create pool of floating ips
i=0
while [ $i -ne 3 ]; do
    flip=`neutron floatingip-create ext-net`
    i=$((i + 1))
done

##http://docs.openstack.org/juno/install-guide/install/apt/content/launch-instance-neutron.html
 netid=`neutron net-show demo-net -c id -f value`
 nova boot --flavor m1.small --image cirros-0.3.4-x86_64 --nic net-id=$netid --security-group default --key-name ubuntu-keypair demo-instance1
 nova floating-ip-associate demo-instance1 $flip
