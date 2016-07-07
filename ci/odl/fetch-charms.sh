#!/bin/bash -ex

distro=$1
mkdir -p $distro

function build {
    sudo apt-get install charm-tools -y
    (cd $distro/charm-congress; charm build -s $distro  -obuild src)
    mv $distro/charm-congress/build/$distro/congress $distro
}

# openstack
bzr branch lp:~narindergupta/charms/trusty/promise/trunk $distro/promise
bzr branch lp:~billy-olsen/charms/xenial/mongodb/trunk $distro/mongodb
bzr branch lp:~narindergupta/opnfv/ntp $distro/ntp
bzr branch lp:~openstack-charmers/charms/trusty/hacluster/next $distro/hacluster
git clone https://github.com/openstack/charm-ceilometer.git $distro/ceilometer
git clone https://github.com/openstack/charm-ceilometer-agent.git $distro/ceilometer-agent
git clone https://github.com/openstack/charm-ceph-mon.git $distro/ceph
git clone https://github.com/openstack/charm-ceph-osd.git $distro/ceph-osd
git clone https://github.com/openstack/charm-ceph-radosgw.git $distro/ceph-radosgw
git clone https://github.com/openstack/charm-cinder.git $distro/cinder
git clone https://github.com/openstack/charm-cinder-ceph.git $distro/cinder-ceph
git clone https://github.com/openstack/charm-glance.git $distro/glance
git clone https://github.com/openstack/charm-keystone.git $distro/keystone
git clone -b stable/16.04 https://github.com/openstack/charm-percona-cluster.git $distro/percona-cluster
git clone https://github.com/openstack/charm-neutron-api.git $distro/neutron-api
git clone https://github.com/openstack/charm-neutron-gateway.git $distro/neutron-gateway
git clone https://github.com/openstack/charm-neutron-openvswitch.git $distro/neutron-openvswitch
git clone https://github.com/openstack/charm-nova-cloud-controller.git $distro/nova-cloud-controller
git clone https://github.com/openstack/charm-nova-compute.git $distro/nova-compute
git clone https://github.com/openstack/charm-openstack-dashboard.git $distro/openstack-dashboard
charm pull cs:~james-page/xenial/rabbitmq-server-bug1590085 $distro/rabbitmq-server
#git clone https://github.com/openstack/charm-rabbitmq-server.git $distro/rabbitmq-server
git clone https://github.com/openstack/charm-heat.git $distro/heat
git clone https://github.com/gnuoy/charm-congress.git $distro/charm-congress
git clone https://github.com/openstack/charm-lxd.git xenial/lxd
build

#controller specific charm
git clone https://github.com/openstack/charm-odl-controller.git $distro/odl-controller
git clone https://github.com/openstack/charm-neutron-api-odl.git $distro/neutron-api-odl
git clone https://github.com/openstack/charm-openvswitch-odl.git $distro/openvswitch-odl
