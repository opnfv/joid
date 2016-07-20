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
    ADMNET_GW=`grep "admNetgway" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //' | tr ',' ' '`
    API_FQDN=`grep "os-domain-name" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //' | tr ',' ' '`
fi

# launch eth on computer nodes and remove default gw route
launch_eth() {
    computer_list=$(juju status --format short | grep -Eo 'nova-compute/[0-9]')
    for node in $computer_list; do
        echo "node name is ${node}"
        juju ssh $node "sudo ifconfig $EXTNET_PORT up"
        #juju ssh $node "sudo route del default gw $ADMNET_GW"
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

keystoneIp() {
    KEYSTONE=$(juju status keystone |grep public-address|sed -- 's/.*\: //')
    if [ $(echo $KEYSTONE|wc -w) == 1 ];then
        echo $KEYSTONE
    else
        juju get keystone | python -c "import yaml; import sys; print yaml.load(sys.stdin)['settings']['vip']['value']"
    fi
}

# create external network and subnet in openstack
create_openrc() {
    mkdir -m 0700 -p cloud
    keystoneIp=$(keystoneIp)
    adminPasswd=$(juju get keystone | grep admin-password -A 5 | grep value | awk '{print $2}' 2> /dev/null)
    configOpenrc admin $adminPasswd admin http://$keystoneIp:5000/v2.0 RegionOne > cloud/admin-openrc
    chmod 0600 cloud/admin-openrc
}

configOpenrc() {
if [ "$API_FQDN" != "''" ]; then
    cat <<-EOF
        export OS_USERNAME=$1
        export OS_PASSWORD=$2
        export OS_TENANT_NAME=$3
        export OS_AUTH_URL=$4
        export OS_REGION_NAME=$5
        export OS_ENDPOINT_TYPE='internalURL'
        export CINDER_ENDPOINT_TYPE='internalURL'
        export GLANCE_ENDPOINT_TYPE='internalURL'
        export KEYSTONE_ENDPOINT_TYPE='internalURL'
        export NEUTRON_ENDPOINT_TYPE='internalURL'
        export NOVA_ENDPOINT_TYPE='internalURL'
EOF
else
    cat <<-EOF
        export OS_USERNAME=$1
        export OS_PASSWORD=$2
        export OS_TENANT_NAME=$3
        export OS_AUTH_URL=$4
        export OS_REGION_NAME=$5
EOF

fi
}

if [ "$API_FQDN" != "''" ]; then
    # Push api fqdn local ip to all /etc/hosts
    API_FQDN=$(juju get keystone | python -c "import yaml; import sys;\
        print yaml.load(sys.stdin)['settings']['os-public-hostname']['value']")

    KEYSTONEIP=$(keystoneIp)
    juju run --all "if grep $API_FQDN /etc/hosts > /dev/null; then \
                        echo 'API FQDN already present'; \
                    else \
                        sudo sh -c 'echo $KEYSTONEIP $API_FQDN >> /etc/hosts'; \
                        echo 'API FQDN injected'; \
                    fi"

    #change in jumphost as well as below commands will run on jumphost

    if grep $API_FQDN /etc/hosts; then
        echo 'API FQDN already present'
    else
        sudo sh -c "echo $KEYSTONEIP $API_FQDN >> /etc/hosts"
        echo 'API FQDN injected'
    fi
fi

# Create an load openrc
create_openrc

. ./cloud/admin-openrc

##
## removing the swift API endpoint which is created by radosgw.
## one option is not to used radosgw and other one is remove endpoint.
##

echo "Removing swift endpoint and service"
swift_service_id=$(openstack service list | grep swift | cut -d ' ' -f 2)
swift_endpoint_id=$(openstack endpoint list | grep swift | cut -d ' ' -f 2)
openstack endpoint delete $swift_endpoint_id
openstack service delete $swift_service_id

##
## Create external subnet Network
##

#neutron net-create ext-net --shared --router:external=True
neutron net-create ext-net --router:external=True

if [ "onos" == "$1" ]; then
    launch_eth
    neutron subnet-create ext-net --name ext-subnet \
       --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
       --disable-dhcp --gateway $EXTNET_GW --dns-nameserver 8.8.8.8 $EXTNET_NET
    #neutron subnet-create ext-net --name ext-subnet $EXTNET_NET
    #update_gw_mac
elif [ "nosdn" == "$1" ]; then
    neutron subnet-create ext-net --name ext-subnet \
       --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
       --disable-dhcp --gateway $EXTNET_GW --dns-nameserver 8.8.8.8 $EXTNET_NET
    # configure security groups
    #neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
    #neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default
else
    neutron subnet-create ext-net --name ext-subnet \
       --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
       --disable-dhcp --gateway $EXTNET_GW --dns-nameserver 8.8.8.8 $EXTNET_NET
fi


# Create Congress datasources
sudo apt-get install -y python-congressclient

# Remove public endpoint and recreate it from internal
# Waiting congress client can be use with internal endpoints
if [ "$API_FQDN" != "''" ]; then
    CONGRESS_PUB_ENDPOINT=$(openstack endpoint list --service policy --interface public -c ID -f value)
    openstack endpoint delete $CONGRESS_PUB_ENDPOINT
    CONGRESS_NEW_PUB_ENDPOINT=$(openstack endpoint list --service policy --interface internal -c URL -f value)
    openstack endpoint create --region RegionOne policy public $CONGRESS_NEW_PUB_ENDPOINT
fi

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


##enable extra stuff only if testing manually

#neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
#neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default

#wget -P /tmp/images http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
#openstack image create --file /tmp/images/cirros-0.3.3-x86_64-disk.img --disk-format qcow2 --container-format bare "cirros-0.3.3-x86_64"
#wget -P /tmp/images http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
#openstack image create --file /tmp/images/trusty-server-cloudimg-amd64-disk1.img --disk-format qcow2 --container-format bare "ubuntu-trusty-daily"
#wget -P /tmp/images http://cloud-images.ubuntu.com/trusty/current/xenial-server-cloudimg-amd64.tar.gz
#openstack image create --file /tmp/images/xenial-server-cloudimg-amd64.tar.gz --container-format bare --disk-format raw "xenial-server-cloudimg-amd64"

#rm -rf /tmp/images

## import key pair
#openstack project create --description "Demo Tenant" demo
#openstack user create --project demo --password demo --email demo@demo.demo demo

#openstack keypair create --public-key ~/.ssh/id_rsa.pub ubuntu-keypair

## create vm network
#neutron net-create demo-net
#neutron subnet-create --name demo-subnet --gateway 10.20.5.1 demo-net 10.20.5.0/24
#neutron router-create demo-router
#neutron router-interface-add demo-router demo-subnet
#neutron router-gateway-set demo-router ext-net

## create pool of floating ips
#i=0
#while [ $i -ne 3 ]; do
#    neutron floatingip-create ext-net
#    i=$((i + 1))
#done

##http://docs.openstack.org/juno/install-guide/install/apt/content/launch-instance-neutron.html
# netid=`neutron net-show demo-net -c id -f value`
# nova boot --flavor m1.small --image cirros-0.3.3-x86_64 --nic net-id=$netid --security-group default --key-name ubuntu-keypair demo-instance1
# nova floating-ip-associate demo-instance1 10.5.15.8

