#!/bin/bash -ex

distro=$1
mkdir -p $distro

function build {
    sudo apt-get install charm-tools -y
    (cd $distro/charm-$1; charm build -s $distro  -obuild src)
    mv $distro/charm-$1/build/$distro/$1 $distro
}

# openstack
bzr branch lp:~narindergupta/charms/trusty/promise/trunk $distro/promise
bzr branch lp:~billy-olsen/charms/xenial/mongodb/trunk $distro/mongodb
bzr branch lp:~narindergupta/opnfv/ntp $distro/ntp

git clone https://github.com/openstack/charm-hacluster.git $distro/hacluster
git clone https://github.com/openstack/charm-ceilometer.git $distro/ceilometer
git clone https://github.com/openstack/charm-ceilometer-agent.git $distro/ceilometer-agent
git clone https://github.com/openstack/charm-ceph-mon.git $distro/ceph-mon
git clone https://github.com/openstack/charm-ceph-osd.git $distro/ceph-osd
git clone https://github.com/openstack/charm-ceph-radosgw.git $distro/ceph-radosgw
git clone https://github.com/openstack/charm-cinder.git $distro/cinder
git clone https://github.com/openstack/charm-cinder-ceph.git $distro/cinder-ceph
git clone https://github.com/openstack/charm-glance.git $distro/glance
git clone https://github.com/openstack/charm-keystone.git $distro/keystone
git clone https://github.com/openstack/charm-percona-cluster.git $distro/percona-cluster
git clone https://github.com/openstack/charm-neutron-api.git $distro/neutron-api
git clone https://github.com/openstack/charm-neutron-gateway.git $distro/neutron-gateway
git clone https://github.com/openstack/charm-neutron-openvswitch.git $distro/neutron-openvswitch
git clone https://github.com/openstack/charm-nova-cloud-controller.git $distro/nova-cloud-controller
git clone https://github.com/openstack/charm-nova-compute.git $distro/nova-compute
git clone https://github.com/openstack/charm-openstack-dashboard.git $distro/openstack-dashboard
git clone https://github.com/openstack/charm-rabbitmq-server.git $distro/rabbitmq-server
git clone https://github.com/openstack/charm-heat.git $distro/heat
git clone https://github.com/openstack/charm-lxd.git $distro/lxd
git clone https://github.com/openbaton/juju-charm.git $distro/openbaton

charm pull cs:$distro/aodh $distro/aodh
charm pull cs:~free.ekanayaka/xenial/haproxy-1 $distro/haproxy
charm pull cs:~narindergupta/congress-1 $distro/congress

#pulling scaleio charms.
charm pull cs:~cloudscaling/scaleio-mdm $distro/scaleio-mdm
charm pull cs:~cloudscaling/scaleio-sds $distro/scaleio-sds
charm pull cs:~cloudscaling/scaleio-gw $distro/scaleio-gw
charm pull cs:~cloudscaling/scaleio-sdc $distro/scaleio-sdc
charm pull cs:~cloudscaling/scaleio-openstack $distro/scaleio-openstack
charm pull cs:~cloudscaling/scaleio-cluster $distro/scaleio-cluster
charm pull cs:~cloudscaling/scaleio-gui $distro/scaleio-gui

git clone https://github.com/Juniper/contrail-charms.git
cd contrail-charms/
mv * ../$distro/
cd ../
rm -rf contrail-charms/

