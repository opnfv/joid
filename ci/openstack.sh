#!/bin/bash -ex

##############################################################################
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

if [ -f ./deployconfig.yaml ];then
    EXTERNAL_NETWORK=`grep floating-ip-range deployconfig.yaml | cut -d ' ' -f 4 `

    # split EXTERNAL_NETWORK=first ip;last ip; gateway;network

    EXTNET=(${EXTERNAL_NETWORK//,/ })

    EXTNET_FIP=${EXTNET[0]}
    EXTNET_LIP=${EXTNET[1]}
    EXTNET_GW=${EXTNET[2]}
    EXTNET_NET=${EXTNET[3]}
    EXTNET_PORT=`grep "ext-port" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //' | tr ',' ' '`
    ADMNET_GW=`grep "admNetworkgway" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //' | tr ',' ' '`

fi

# launch eth on computer nodes and remove default gw route
launch_eth() {
    computer_list=$(juju status --format short | grep -Eo 'nova-compute/[0-9]')
    for node in $computer_list; do
        echo "node name is ${node}"
        juju ssh $node "sudo ifconfig $EXTNET_PORT up"
        juju ssh $node "sudo route del default gw $ADMNET_GW"
    done
}

# Update gateway mac to onos for l3 function
update_gw_mac() {
    ## get gateway mac
    EXTNET_GW_MAC=$(juju ssh nova-compute/0 "arp -a ${EXTNET_GW} | grep -Eo '([0-9a-fA-F]{2})(([/\s:-][0-9a-fA-F]{2}){5})'")
    ## set external gateway mac in onos
    juju set onos-controller gateway-mac=$EXTNET_GW_MAC
}

unitAddress() {
        juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"$1\"][\"units\"][\"$1/$2\"][\"public-address\"]" 2> /dev/null
}

unitMachine() {
        juju status | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"$1\"][\"units\"][\"$1/$2\"][\"machine\"]" 2> /dev/null
}

# create external network and subnet in openstack
create_openrc() {
    mkdir -m 0700 -p cloud
    keystoneIp=$(juju get keystone | grep vip: -A 7 | grep value | awk '{print $2}')
    if [ -z "$keystoneIp" ]; then
        keystoneIp=$(unitAddress keystone 0)
    fi
    adminPasswd=$(juju get keystone | grep admin-password -A 5 | grep value | awk '{print $2}')
    configOpenrc admin $adminPasswd admin http://$keystoneIp:5000/v2.0 Canonical > cloud/admin-openrc
    chmod 0600 cloud/admin-openrc
}

configOpenrc() {
	cat <<-EOF
		export OS_USERNAME=$1
		export OS_PASSWORD=$2
		export OS_TENANT_NAME=$3
		export OS_AUTH_URL=$4
		export OS_REGION_NAME=$5
		EOF
}

create_openrc

. ./cloud/admin-openrc

wget -P /tmp/images http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
glance image-create --name "cirros-0.3.3-x86_64" --file /tmp/images/cirros-0.3.3-x86_64-disk.img --disk-format qcow2 --container-format bare --progress

#wget -P /tmp/images http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
#glance image-create --name "ubuntu-trusty-daily" --file /tmp/images/trusty-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare --progress
rm -rf /tmp/images

# adjust tiny image
#nova flavor-delete m1.tiny
#nova flavor-create m1.tiny 1 512 8 1


# import key pair
keystone tenant-create --name demo --description "Demo Tenant"
keystone user-create --name demo --tenant demo --pass demo --email demo@demo.demo

nova keypair-add --pub-key ~/.ssh/id_rsa.pub ubuntu-keypair

# configure external network

##
## Create external subnet Network
##
if [ "onos" == "$1" ]; then
    launch_eth
    neutron net-create ext-net --shared --router:external=True
    neutron subnet-create ext-net --name ext-subnet $EXTNET_NET
    update_gw_mac
else
    neutron net-create ext-net --shared --router:external --provider:physical_network external --provider:network_type flat
    neutron subnet-create ext-net --name ext-subnet \
       --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
          --disable-dhcp --gateway $EXTNET_GW $EXTNET_NET
    # configure security groups
    neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
    neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default
fi


# create vm network
neutron net-create demo-net
neutron subnet-create --name demo-subnet --gateway 10.20.5.1 demo-net 10.20.5.0/24

neutron router-create demo-router

neutron router-interface-add demo-router demo-subnet

neutron router-gateway-set demo-router ext-net

# create pool of floating ips
i=0
while [ $i -ne 3 ]; do
	neutron floatingip-create ext-net
	i=$((i + 1))
done

#http://docs.openstack.org/juno/install-guide/install/apt/content/launch-instance-neutron.html
# nova boot --flavor m1.small --image cirros-0.3.3-x86_64 --nic net-id=b65479a4-3638-4595-9245-6e41ccd8bfd8 --security-group default --key-name ubuntu-keypair demo-instance1
# nova floating-ip-associate demo-instance1 10.5.8.35

# Create Congress datasources
sudo apt-get install -y python-congressclient
openstack congress datasource create nova "nova" \
  --config username=$OS_USERNAME \
  --config tenant_name=$OS_TENANT_NAME \
  --config password=$OS_PASSWORD \
  --config auth_url=http://$keystoneIp:5000/v2.0
openstack congress datasource create neutronv2 "neutronv2" \
  --config username=$OS_USERNAME \
  --config tenant_name=$OS_TENANT_NAME \
  --config password=$OS_PASSWORD \
  --config auth_url=http://$keystoneIp:5000/v2.0
openstack congress datasource create ceilometer "ceilometer" \
  --config username=$OS_USERNAME \
  --config tenant_name=$OS_TENANT_NAME \
  --config password=$OS_PASSWORD \
  --config auth_url=http://$keystoneIp:5000/v2.0
openstack congress datasource create cinder "cinder" \
  --config username=$OS_USERNAME \
  --config tenant_name=$OS_TENANT_NAME \
  --config password=$OS_PASSWORD \
  --config auth_url=http://$keystoneIp:5000/v2.0
openstack congress datasource create glancev2 "glancev2" \
  --config username=$OS_USERNAME \
  --config tenant_name=$OS_TENANT_NAME \
  --config password=$OS_PASSWORD \
  --config auth_url=http://$keystoneIp:5000/v2.0
openstack congress datasource create keystone "keystone" \
  --config username=$OS_USERNAME \
  --config tenant_name=$OS_TENANT_NAME \
  --config password=$OS_PASSWORD \
  --config auth_url=http://$keystoneIp:5000/v2.0
