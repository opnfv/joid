#!/bin/bash -ex
##############################################################################
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -ex

source common/tools.sh

#./openstack.sh "$opnfvsdn" "$opnfvlab" "$opnfvdistro" "$openstack" || true

opnfvsdn=$1
opnfvlab=$2
opnfvdistro=$3
opnfvos=$4

jujuver=`juju --version`

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
    if [[ "$jujuver" < "2" ]]; then
        juju set onos-controller gateway-mac=$EXTNET_GW_MAC
    else
        juju config onos-controller gateway-mac=$EXTNET_GW_MAC
    fi
}

unitAddress() {
    if [[ "$jujuver" < "2" ]]; then
        juju status --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"$1\"][\"units\"][\"$1/$2\"][\"public-address\"]" 2> /dev/null
    else
        juju status --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"applications\"][\"$1\"][\"units\"][\"$1/$2\"][\"public-address\"]" 2> /dev/null
    fi
}

unitMachine() {
    if [[ "$jujuver" < "2" ]]; then
        juju status --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"$1\"][\"units\"][\"$1/$2\"][\"machine\"]" 2> /dev/null
    else
        juju status --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"applications\"][\"$1\"][\"units\"][\"$1/$2\"][\"machine\"]" 2> /dev/null
    fi
}

keystoneIp() {
    if [ $(juju status keystone --format=short | grep " keystone"|wc -l) == 1 ];then
        unitAddress keystone 0
    else
        if [[ "$jujuver" < "2" ]]; then
            juju get keystone | python -c "import yaml; import sys; print yaml.load(sys.stdin)['settings']['vip']['value']" | cut -d " " -f 1
        else
            juju config keystone | python -c "import yaml; import sys; print yaml.load(sys.stdin)['settings']['vip']['value']" | cut -d " " -f 1
        fi
    fi
}

# create external network and subnet in openstack
create_openrc() {
    echo_info "Creating the openrc (OpenStack client environment scripts)"

    mkdir -m 0700 -p cloud
    keystoneIp=$(keystoneIp)
    if [[ "$jujuver" < "2" ]]; then
        adminPasswd=$(juju get keystone | grep admin-password -A 5 | grep value | awk '{print $2}' 2> /dev/null)
    else
        adminPasswd=$(juju config keystone | grep admin-password -A 5 | grep value | awk '{print $2}' 2> /dev/null)
    fi

    v3api=`juju config keystone  preferred-api-version`

    if [[ "$v3api" == "3" ]]; then
        configOpenrc admin $adminPasswd admin http://$keystoneIp:5000/v3 RegionOne publicURL > ~/joid_config/admin-openrc
        chmod 0600 ~/joid_config/admin-openrc
        source ~/joid_config/admin-openrc
        projectid=`openstack project show admin -c id -f value`
        projectdomainid=`openstack domain show admin_domain -c id -f value`
        userdomainid=`openstack user show admin -c domain_id -f value`
        urlapi=`openstack catalog show keystone --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)['endpoints']" | grep public | cut -d " " -f 4`
        configOpenrc admin $adminPasswd admin $urlapi RegionOne > ~/joid_config/admin-openrc
    else
        configOpenrc2 admin $adminPasswd admin http://$keystoneIp:5000/v2.0 RegionOne > ~/joid_config/admin-openrc
        chmod 0600 ~/joid_config/admin-openrc
    fi
}

configOpenrc2() {
cat <<-EOF
export SERVICE_ENDPOINT=$4
unset SERVICE_TOKEN
unset SERVICE_ENDPOINT
export OS_USERNAME=$1
export OS_PASSWORD=$2
export OS_TENANT_NAME=$3
export OS_AUTH_URL=$4
export OS_REGION_NAME=$5
EOF
}

configOpenrc() {
cat <<-EOF
#export OS_NO_CACHE='true'
export OS_AUTH_URL=$4
export OS_USER_DOMAIN_NAME=admin_domain
export OS_PROJECT_DOMAIN_NAME=admin_domain
export OS_USERNAME=$1
export OS_TENANT_NAME=$3
export OS_PROJECT_NAME=$3
export OS_PASSWORD=$2
export OS_VOLUME_API_VERSION=2
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_REGION_NAME=$5
EOF
}

# Create an load openrc
create_openrc

. ~/joid_config/admin-openrc

##
## removing the swift API endpoint which is created by radosgw.
## one option is not to used radosgw and other one is remove endpoint.
##

#echo "Removing swift endpoint and service"
#swift_service_id=$(openstack service list | grep swift | cut -d ' ' -f 2)
#swift_endpoint_id=$(openstack endpoint list | grep swift | cut -d ' ' -f 2)
#openstack endpoint delete $swift_endpoint_id
#openstack service delete $swift_service_id

##
## Create external subnet Network
##

echo_info "Creating external network with neutron"

if [ "onos" == "$opnfvsdn" ]; then
    launch_eth
    neutron net-show ext-net > /dev/null 2>&1 || neutron net-create ext-net \
                                                   --router:external=True
else
    neutron net-show ext-net > /dev/null 2>&1 || neutron net-create ext-net \
                                                   --router:external=True \
                                                   --provider:network_type flat \
                                                   --provider:physical_network physnet1
fi

neutron subnet-show ext-subnet > /dev/null 2>&1 || neutron subnet-create ext-net \
   --name ext-subnet --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
   --disable-dhcp --gateway $EXTNET_GW $EXTNET_NET

#congress team is not updating and supporting charm anymore so defer it.

# Create Congress datasources
#sudo apt-get install -y python-congressclient

#openstack congress datasource create nova "nova" \
#  --config username=$OS_USERNAME \
#  --config tenant_name=$OS_TENANT_NAME \
#  --config password=$OS_PASSWORD \
#  --config auth_url=http://$keystoneIp:5000/v2.0
#openstack congress datasource create neutronv2 "neutronv2" \
#  --config username=$OS_USERNAME \
#  --config tenant_name=$OS_TENANT_NAME \
#  --config password=$OS_PASSWORD \
#  --config auth_url=http://$keystoneIp:5000/v2.0
#openstack congress datasource create ceilometer "ceilometer" \
#  --config username=$OS_USERNAME \
#  --config tenant_name=$OS_TENANT_NAME \
#  --config password=$OS_PASSWORD \
#  --config auth_url=http://$keystoneIp:5000/v2.0
#openstack congress datasource create cinder "cinder" \
#  --config username=$OS_USERNAME \
#  --config tenant_name=$OS_TENANT_NAME \
#  --config password=$OS_PASSWORD \
#  --config auth_url=http://$keystoneIp:5000/v2.0
#openstack congress datasource create glancev2 "glancev2" \
#  --config username=$OS_USERNAME \
#  --config tenant_name=$OS_TENANT_NAME \
#  --config password=$OS_PASSWORD \
#  --config auth_url=http://$keystoneIp:5000/v2.0
#openstack congress datasource create keystone "keystone" \
#  --config username=$OS_USERNAME \
#  --config tenant_name=$OS_TENANT_NAME \
#  --config password=$OS_PASSWORD \
#  --config auth_url=http://$keystoneIp:5000/v2.0
