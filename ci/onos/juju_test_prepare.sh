#!/bin/bash

# launch eth on computer nodes and remove default gw route
# Update gateway mac to onos for l3 function

# author: York(Yuanyou)
# set the gateway ip and cidr and compute-node eth name.
case "$1" in
    'orangepod2' )
       GW_IP=192.168.2.1
       CIDR=161.105.231.0/26
       COMPUTE_ETH=eth1
        ;;
     'intelpod6' )
       GW_IP=10.6.15.254
       CIDR=10.6.15.0/24
       COMPUTE_ETH=eth5
        ;;
     'intelpod5' )
       GW_IP=10.5.15.254
       CIDR=10.5.15.0/24
       COMPUTE_ETH=eth5
        ;;
     'attvirpod1' )
       GW_IP=10.10.15.1
       CIDR=10.10.15.0/24
       COMPUTE_ETH=eth1
        ;;
     'default' )
       GW_IP=192.168.122.1
       CIDR=192.168.122.0/24
       COMPUTE_ETH=eth1
        ;;
     * )
       GW_IP=192.168.122.1
       CIDR=192.168.122.0/24
       COMPUTE_ETH=eth1
        ;;
esac

# launch eth on computer nodes and remove default gw route
launch_eth() {
  computer_list=$(juju status --format short | grep -Eo 'nodes-compute/[0-9]')
  for node in $computer_list; do
    echo "node name is ${node}"
    juju ssh $node "sudo ifconfig $COMPUTE_ETH up"
    juju ssh $node "sudo route del default gw $GW_IP"
  done
}

# create external network and subnet in openstack
create_ext_network() {
  keystoneIp=$(juju status --format short | grep keystone/0 | grep -v ha | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
  adminPasswd=$(juju get keystone | grep admin-password -A 5 | grep value | awk '{print $2}')
  configOpenrc admin $adminPasswd admin http://$keystoneIp:5000/v2.0 Canonical
  juju scp ./admin-openrc nova-cloud-controller/0:
  juju ssh nova-cloud-controller/0 "source admin-openrc;neutron net-create ext-net --shared --router:external=True;neutron subnet-create ext-net --name ext-subnet $CIDR"
}

configOpenrc()
{
    echo  "  " > ./admin-openrc
    echo  "export OS_USERNAME=$1" >> ./admin-openrc
    echo  "export OS_PASSWORD=$2" >> ./admin-openrc
    echo  "export OS_TENANT_NAME=$3" >> ./admin-openrc
    echo  "export OS_AUTH_URL=$4" >> ./admin-openrc
    echo  "export OS_REGION_NAME=$5" >> ./admin-openrc
 }

# Update gateway mac to onos for l3 function
update_gw_mac() {
  ## get gateway mac
  GW_MAC=$(juju ssh nova-compute/0 "arp -a ${GW_IP} | grep -Eo '([0-9a-fA-F]{2})(([/\s:-][0-9a-fA-F]{2}){5})'")
  ## set external gateway mac in onos
  juju set onos-controller gateway-mac=$GW_MAC

}

main() {
  launch_eth
  create_ext_network
  update_gw_mac
}

main "$@"
