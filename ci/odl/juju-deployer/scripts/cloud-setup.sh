#!/bin/sh -e

. ~/admin-openrc

# adjust tiny image
nova flavor-delete m1.tiny
nova flavor-create m1.tiny 1 512 8 1

# configure security groups
neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default

# import key pair
keystone tenant-create --name demo --description "Demo Tenant"
keystone user-create --name demo --tenant demo --pass demo --email demo@demo.demo

nova keypair-add --pub-key ~/.ssh/id_rsa.pub ubuntu-keypair

# configure external network
neutron net-create --router:external --provider:physical_network external --provider:network_type flat  ext-net
neutron subnet-create --name ext-subnet --no-gateway --allocation-pool start=10.2.65.201,end=10.2.65.255 --disable-dhcp ext-net 10.2.65.0/24

# create vm network
neutron net-create demo-net
neutron subnet-create --name demo-subnet --gateway 10.20.5.1 demo-net 10.20.5.0/24

neutron router-create demo-router

neutron router-interface-add demo-router demo-subnet

neutron router-gateway-set demo-router ext-net

# create pool of floating ips
i=0
while [ $i -ne 10 ]; do
	neutron floatingip-create public-net
	i=$((i + 1))
done

