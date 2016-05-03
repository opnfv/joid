#!/bin/bash
#placeholder for deployment script.
set -ex

#copy and download charms
    cp $4/fetch-charms.sh ./fetch-charms.sh
    sh ./fetch-charms.sh


case "$1" in
    'nonha' )
        cp $4/juju-deployer/ovs-$4-nonha.yaml ./bundles.yaml
        ;;
    'ha' )
        cp $4/juju-deployer/ovs-$4-ha.yaml ./bundles.yaml
        ;;
    'tip' )
        cp $4/juju-deployer/ovs-$4-tip.yaml ./bundles.yaml
        cp common/source/* ./
        sed -i -- "s|branch: master|branch: stable/$2|g" ./*.yaml
        ;;
    * )
        cp $4/juju-deployer/ovs-$4-nonha.yaml ./bundles.yaml
        ;;
esac

case "$3" in
    'orangepod1' )
        # As per your lab vip address list be deafult uses 10.4.1.11 - 10.4.1.20
         sed -i -- 's/10.4.1.1/192.168.1.2/g' ./bundles.yaml
        # choose the correct interface to use for data network
         sed -i -- 's/#os-data-network: 10.4.8.0\/21/os-data-network: 192.168.11.0\/24/g' ./bundles.yaml
        # Choose the external port to go out from gateway to use.
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1"/g' ./bundles.yaml
        # Use host for public API for Orange pod2
        # sed -i -- 's/#os-public-hostname: api.public-fqdn/os-public-hostname: api.pod2.opnfv.fr/g' ./bundles.yaml
         ;;
    'orangepod2' )
        # As per your lab vip address list be deafult uses 10.4.1.11 - 10.4.1.20
         sed -i -- 's/10.4.1.1/192.168.2.2/g' ./bundles.yaml
        # choose the correct interface to use for data network
         sed -i -- 's/#os-data-network: 10.4.8.0\/21/os-data-network: 192.168.12.0\/24/g' ./bundles.yaml
        # Choose the external port to go out from gateway to use.
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1"/g' ./bundles.yaml
        # Use host for public API for Orange pod2
        # sed -i -- 's/#os-public-hostname: api.public-fqdn/os-public-hostname: api.pod2.opnfv.fr/g' ./bundles.yaml
         ;;
     'intelpod6' )
        # As per your lab vip address list be deafult uses 10.4.1.11 - 10.4.1.20
         sed -i -- 's/10.4.1.1/10.6.1.2/g' ./bundles.yaml
        # choose the correct interface to use for data network
         sed -i -- 's/#os-data-network: 10.4.8.0\/21/os-data-network: 10.6.12.0\/24/g' ./bundles.yaml
        # Choose the external port to go out from gateway to use.
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth5"/g' ./bundles.yaml
        # Provide the gateway MAC to route the traffic externally.
         sed -i -- 's/#gateway-mac: "default"/gateway-mac: "default"/g' ./bundles.yaml
         ;;
     'intelpod5' )
        # As per your lab vip address list be deafult uses 10.4.1.11 - 10.4.1.20
         sed -i -- 's/10.4.1.1/10.5.1.2/g' ./bundles.yaml
        # choose the correct interface to use for data network
         sed -i -- 's/#os-data-network: 10.4.8.0\/21/os-data-network: 10.5.12.0\/24/g' ./bundles.yaml
        # Choose the external port to go out from gateway to use.
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth5"/g' ./bundles.yaml
        # Provide the gateway MAC to route the traffic externally.
         sed -i -- 's/#gateway-mac: "default"/gateway-mac: "default"/g' ./bundles.yaml
        ;;
     'attvirpod1' )
        # As per your lab vip address list be deafult uses 10.4.1.11 - 10.4.1.20
         sed -i -- 's/10.4.1.1/192.168.10.1/g' ./bundles.yaml
        # Choose the external port to go out from gateway to use.
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1"/g' ./bundles.yaml
        ;;
     'cengnlynxpod1' )
        # Chose the hard drive(s) to use for CEPH OSD
         sed -i -- 's|osd-devices: /srv|osd-devices: /dev/sdb|g' ./bundles.yaml
        # As per your lab vip address list be deafult uses 10.4.1.11 - 10.4.1.20
         sed -i -- 's/10.4.1.1/10.120.0.1/g' ./bundles.yaml
        # choose the correct interface to use for data network
         sed -i -- 's/#os-data-network: 10.4.8.0\/21/os-data-network: 172.16.121.0\/24/g' ./bundles.yaml
        # Choose the external port to go out from gateway to use.
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1.1202"/g' ./bundles.yaml
        ;;
     'juniperpod1' )
         sed -i -- 's/10.4.1.1/172.16.50.1/g' ./bundles.yaml
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1"/g' ./bundles.yaml
         ;;
     'ravellodemopod' )
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth2"/g' ./bundles.yaml
        ;;
     'custom' )
         sed -i -- 's/10.4.1.1/192.168.122.1/g' ./bundles.yaml
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1"/g' ./bundles.yaml
        ;;
     'default' )
         sed -i -- 's/10.4.1.1/192.168.122.1/g' ./bundles.yaml
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1"/g' ./bundles.yaml
        ;;
esac

case "$5" in
    'ipv6' )
         sed -i -- 's/#prefer-ipv6: true/prefer-ipv6: true/g' ./bundles.yaml
        ;;
    'dvr' )
         sed -i -- 's/#enable-dvr: true/enable-dvr: true/g' ./bundles.yaml
         sed -i -- 's/#l2-population: true/l2-population: true/g' ./bundles.yaml
        ;;
    'sfc' )
         sed -i -- 's/profile: "openvswitch-odl-Be"/profile: "openvswitch-odl-beryllium-sfc"/g' ./bundles.yaml
        ;;
    'vpn' )
         sed -i -- 's/profile: "openvswitch-odl-Be"/profile: "openvswitch-odl-beryllium-vpn"/g' ./bundles.yaml
        ;;
    'odl_l3' )
         sed -i -- 's/profile: "openvswitch-odl-Be"/profile: "openvswitch-odl-beryllium-l3"/g' ./bundles.yaml
        ;;
esac

echo "... Deployment Started ...."
case "$1" in
    'nonha' )
        juju-deployer -vW -d -t 3600 -c bundles.yaml trusty-"$2"-nodes
        juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml trusty-"$2"
        ;;
    'ha' )
        juju-deployer -vW -d -t 3600 -c bundles.yaml trusty-"$2"-nodes
        juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml trusty-"$2"
        ;;
    'tip' )
        juju-deployer -vW -d -t 3600 -c bundles.yaml trusty-"$2"-nodes
        juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml trusty-"$2"
        ;;
    * )
        juju-deployer -vW -d -t 3600 -c bundles.yaml trusty-"$2"-nodes
        juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml trusty-"$2"
        ;;
esac

#case "$4" in
#    'onos' )
#         echo "... onos prepare test ..."
#         sleep 180s
#         sh onos/juju_test_prepare.sh "$3"
#        ;;
#esac
