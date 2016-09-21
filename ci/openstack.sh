#!/bin/bash -ex

##############################################################################
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

#./openstack.sh "$opnfvsdn" "$opnfvlab" "$opnfvdistro" "$openstack" || true

opnfvsdn=$1
opnfvlab=$2
opnfvdistro=$3
opnfvos=$4

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
if [ "$API_FQDN" != "None" ]; then
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

if [ "$API_FQDN" != "None" ]; then
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

    # remove this enhancement for heat that does not manage endpoints
    juju run --service=heat "cp /etc/hosts /tmp/hosts ; \
                             grep -v $API_FQDN /tmp/hosts > /etc/hosts"

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

echo "...... deploy public api proxy ......"

if ([ "$opnfvlab" == "orangepod1" ] \
    || [ "$opnfvlab" == "intelpod6" ]) \
    && [ "$opnfvsdn" == "nosdn" ] \
    && [ "$API_FQDN" != "None" ]; then # only for first test phase
    if [ -e ./labconfig.yaml ]; then
        PUB_API_MASK=$(grep floating-ip-range ./labconfig.yaml |cut -d/ -f2)
        PUB_API_NET=$(grep floating-ip-range ./labconfig.yaml |cut -d, -f4)
        PUB_API_IP=$(grep public-api-ip ./labconfig.yaml |cut -d: -f2)
        if grep "- type: public" ./labconfig.yaml; then
            # The public network exists on MAAS, so we push the dns record to it

            # Recover maas ips and login to it
            maas_ip=$(grep " ip_address" deployment.yaml | cut -d ':' -f 2 | sed -e 's/ //')
            maas_pubip=$(grep floating-ip-range ./labconfig.yaml |cut -d, -f4 |perl -pe 's!^(.*)\.\d+/\d+$!$1.5!')
            apikey=$(grep maas-oauth: environments.yaml | cut -d "'" -f 2)
            maas login maas http://${maas_ip}/MAAS/api/1.0 ${apikey}

            # Configure maas to add the record
            CLUSTER_UUID=$(maas ubuntu node-groups list | grep uuid | cut -d\" -f4)
            PUBLIC_MAAS_IF=$(maas ubuntu node-group-interfaces list $cluster_uuid |\
                             python -c "import yaml; import sys; cfg=yaml.load(sys.stdin); net_h={net['ip']:net['name'] for net in cfg}; print(net_h['$maas_pubip'])")
            maas maas node-group-interface update ${CLUSTER_UUID} ${PUBLIC_MAAS_IF} static_ip_range_high=${PUB_API_IP} static_ip_range_low=${PUB_API_IP}
            maas maas ipaddresses reserve network=${PUB_API_NET} requested_address=${PUB_API_IP} hostname=${API_FQDN}
            dig ${PUB_API_IP} @${maas_ip} # just for log
        fi
        juju run --unit nodes/0 "sudo ip a a ${PUB_API_IP}/${PUB_API_MASK} dev br-ex" || true
        juju run --unit nodes/0 "sudo ip l set dev br-ex up" || true
        python genPublicAPIProxyBundle.py -l labconfig.yaml >> bundles.yaml
        juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml $opnfvdistro-"$opnfvos" || true
    fi
fi

echo "...... deploy end public api proxy ......"

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

if [ "onos" == "$opnfvsdn" ]; then
    launch_eth
    neutron net-show ext-net > /dev/null 2>&1 || neutron net-create ext-net --router:external=True
    neutron subnet-show ext-subnet > /dev/null 2>&1 || neutron subnet-create ext-net \
       --name ext-subnet --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
       --disable-dhcp --gateway $EXTNET_GW $EXTNET_NET
    #neutron subnet-create ext-net --name ext-subnet $EXTNET_NET
    #update_gw_mac
elif [ "nosdn" == "$opnfvsdn" ]; then
    neutron net-show ext-net > /dev/null 2>&1 || neutron net-create ext-net \
                                             --router:external=True \
                                             --provider:network_type flat \
                                              --provider:physical_network external

    neutron subnet-show ext-subnet > /dev/null 2>&1 || neutron subnet-create ext-net \
       --name ext-subnet --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
       --disable-dhcp --gateway $EXTNET_GW $EXTNET_NET
else
    neutron net-show ext-net > /dev/null 2>&1 || neutron net-create ext-net --router:external=True
    neutron subnet-show ext-subnet > /dev/null 2>&1 || neutron subnet-create ext-net \
       --name ext-subnet --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
       --disable-dhcp --gateway $EXTNET_GW $EXTNET_NET
fi


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
