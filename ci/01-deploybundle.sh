#!/bin/bash
#placeholder for deployment script.
set -ex

#    ./01-deploybundle.sh $opnfvtype $openstack $opnfvlab $opnfvsdn $opnfvfeature $opnfvdistro

    #copy and download charms
    cp $4/fetch-charms.sh ./fetch-charms.sh
    #modify the ubuntu series wants to deploy
    sed -i -- "s|distro=trusty|distro=$6|g" ./fetch-charms.sh
    sh ./fetch-charms.sh $6


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


#read the value from deployment.yaml
if [ -e ~/.juju/deployment.yaml ]; then
   extport=`grep "ext-port" deployment.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
   sed --i "s@#ext-port: \"eth1\"@ext-port: \"$extport\"@g" ./bundles.yaml

   datanet=`grep "dataNetwork" deployment.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
   sed --i "s@#os-data-network: 10.4.8.0/21@os-data-network: $datanet@g" ./bundles.yaml

   admnet=`grep "admNetwork" deployment.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
   sed --i "s@10.4.1.1@$admnet@g" ./bundles.yaml

   cephdisk=`grep "disk" deployment.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
   sed --i "s@osd-devices: /srv@osd-devices: $cephdisk@g" ./bundles.yaml
fi

case "$3" in
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
     'default' )
         sed -i -- 's/10.4.1.1/192.168.122.1/g' ./bundles.yaml
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1"/g' ./bundles.yaml
        ;;
esac

# lets put the if seperateor as "," as this will save me from world.
IFS=","

for feature in $5; do
    case "$feature" in
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
        'dpdk' )
             sed -i -- 's/#enable-dpdk: true/enable-dpdk: true/g' ./bundles.yaml
             sed -i -- 's/#hugepages: "50%"/hugepages: "50%"/g' ./bundles.yaml
            ;;
        'lxd' )
             sed -i -- 's/#- - nova-compute:lxd/- - nova-compute:lxd/g' ./bundles.yaml
             sed -i -- 's/#- lxd:lxd/- lxd:lxd/g' ./bundles.yaml
             sed -i -- 's/#virt-type: lxd/virt-type: lxd/g' ./bundles.yaml
             # adding the lxd subordinate charm
             echo "    lxd:" >> ./bundles.yaml
             echo "      charm: local:xenial/lxd" >> ./bundles.yaml
            ;;
    esac
done

#changing the target to the openstack release we want to deploy.
sed -i -- "s|mitaka|$2|g" ./bundles.yaml

#update source if trusty is target distribution
case "$6" in
    'trusty' )
        sed -i -- "s|#source|source|g" ./bundles.yaml
        ;;
    'xenial' )
        #changing the target to the ubuntu distro we want to deploy.
        sed -i -- "s|trusty|$6|g" ./bundles.yaml
        ;;
esac

echo "... Deployment Started ...."
    juju-deployer -vW -d -t 3600 -c bundles.yaml $6-"$2"-nodes
    juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml $6-"$2"

