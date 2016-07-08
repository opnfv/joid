#!/bin/bash
#placeholder for deployment script.
set -ex

#    ./01-deploybundle.sh $opnfvtype $openstack $opnfvlab $opnfvsdn $opnfvfeature $opnfvdistro

    #copy and download charms
    cp $4/fetch-charms.sh ./fetch-charms.sh
    #modify the ubuntu series wants to deploy
    sed -i -- "s|distro=trusty|distro=$6|g" ./fetch-charms.sh
    ./fetch-charms.sh $6

osdomname=''

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

#check whether charms are still executing the code even juju-deployer says installed.
check_status() {
    retval=0
    timeoutiter=0
    while [ $retval -eq 0 ]; do
       sleep 30
       juju status > status.txt
       if [ "$(grep -c "executing" status.txt )" -ge 2 ]; then
           echo " still executing the reltionship within charms ..."
           if [ $timeoutiter -ge 60 ]; then
               retval=1
           fi
           timeoutiter=$((timeoutiter+1))
       else
           retval=1
       fi
    done
    echo "...... deployment finishing ......."
}

#read the value from deployment.yaml
if [ -e ~/.juju/deployment.yaml ]; then
   cp ~/.juju/deployment.yaml ./deployment.yaml
   if [ -e ~/.juju/deployconfig.yaml ]; then
      cp ~/.juju/deployconfig.yaml ./deployconfig.yaml
      extport=`grep "ext-port" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //' | tr ',' ' '`
      sed --i "s@#ext-port: \"eth1\"@ext-port: \"$extport\"@g" ./bundles.yaml
      datanet=`grep "dataNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
      if [ "$datanet" != "''" ]; then
          sed -i -- "s@#os-data-network: 10.4.8.0/21@os-data-network: $datanet@g" ./bundles.yaml
      fi
      admnet=`grep "admNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
      sed --i "s@10.4.1.1@$admnet@g" ./bundles.yaml
      cephdisk=`grep "ceph-disk" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
      sed --i "s@osd-devices: /srv@osd-devices: $cephdisk@g" ./bundles.yaml
      osdomname=`grep "os-domain-name" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
      if [ "$osdomname" != "''" ]; then
          sed --i "s@#use-internal-endpoints: true@use-internal-endpoints: true@g" ./bundles.yaml
          sed --i "s@#endpoint-type: internalURL@endpoint-type: internalURL@g" ./bundles.yaml
          sed --i "s@#os-public-hostname: pod.maas@os-public-hostname: api.$osdomname@g" ./bundles.yaml
          sed --i "s@#console-proxy-ip: pod.maas@console-proxy-ip: $osdomname@g" ./bundles.yaml
      fi
   fi
fi

case "$3" in
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
fea=""
IFS=","
for feature in $5; do
    if [ "$fea" == "" ]; then
        fea=$feature
    else
        fea=$fea"_"$feature
    fi
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
        sed -i -- "s|#source-branch:|source-branch:|g" ./bundles.yaml
        ;;
    'xenial' )
        #changing the target to the ubuntu distro we want to deploy.
        sed -i -- "s|trusty|$6|g" ./bundles.yaml
        ;;
esac

if [ "$osdomname" != "''" ]; then
    var=os-$4-$fea-$1-publicapi
else
    var=os-$4-$fea-$1
fi

#lets generate the bundle for all target using genBundle.py
python genBundle.py  -l deployconfig.yaml  -s $var > bundles.yaml

echo "... Deployment Started ...."
    juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml $6-"$2"-nodes
    juju ssh nodes/0 "echo 512 | sudo tee /proc/sys/fs/inotify/max_user_instances"
    juju ssh nodes/1 "echo 512 | sudo tee /proc/sys/fs/inotify/max_user_instances"
    juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml $6-"$2"
    #check_status
