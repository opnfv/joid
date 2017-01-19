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

git clone https://github.com/gnuoy/charm-congress.git $distro/charm-congress
build congress

git clone https://github.com/openstack/charm-hacluster.git $distro/hacluster
git clone   https://github.com/openstack/charm-ceilometer.git $distro/ceilometer
git clone   https://github.com/openstack/charm-ceilometer-agent.git $distro/ceilometer-agent
git clone   https://github.com/openstack/charm-ceph-mon.git $distro/ceph-mon
git clone   https://github.com/openstack/charm-ceph-osd.git $distro/ceph-osd
git clone   https://github.com/openstack/charm-ceph-radosgw.git $distro/ceph-radosgw
git clone   https://github.com/openstack/charm-cinder.git $distro/cinder
git clone   https://github.com/openstack/charm-cinder-ceph.git $distro/cinder-ceph
git clone   https://github.com/openstack/charm-glance.git $distro/glance
git clone   https://github.com/openstack/charm-keystone.git $distro/keystone
git clone   https://github.com/openstack/charm-percona-cluster.git $distro/percona-cluster
git clone   https://github.com/openstack/charm-neutron-api.git $distro/neutron-api
git clone   https://github.com/openstack/charm-neutron-gateway.git $distro/neutron-gateway
git clone   https://github.com/openstack/charm-neutron-openvswitch.git $distro/neutron-openvswitch
git clone   https://github.com/openstack/charm-nova-cloud-controller.git $distro/nova-cloud-controller
git clone   https://github.com/openstack/charm-nova-compute.git $distro/nova-compute
git clone   https://github.com/openstack/charm-openstack-dashboard.git $distro/openstack-dashboard
git clone   https://github.com/openstack/charm-rabbitmq-server.git $distro/rabbitmq-server
git clone   https://github.com/openstack/charm-heat.git $distro/heat
git clone   https://github.com/openstack/charm-lxd.git xenial/lxd

charm pull cs:$distro/aodh $distro/aodh
charm pull cs:~free.ekanayaka/xenial/haproxy-1 $distro/haproxy
#charm pull cs:~openstack-charmers-next/hacluster $distro/hacluster
#charm pull cs:~openstack-charmers-next/ceilometer $distro/ceilometer
#charm pull cs:~openstack-charmers-next/ceilometer-agent $distro/ceilometer-agent
#charm pull cs:~openstack-charmers-next/ceph-mon $distro/ceph
#charm pull cs:~openstack-charmers-next/ceph-osd $distro/ceph-osd
#charm pull cs:~openstack-charmers-next/ceph-radosgw $distro/ceph-radosgw
#charm pull cs:~openstack-charmers-next/cinder $distro/cinder
#charm pull cs:~openstack-charmers-next/cinder-ceph $distro/cinder-ceph
#charm pull cs:~openstack-charmers-next/glance $distro/glance
#charm pull cs:~openstack-charmers-next/keystone $distro/keystone
#charm pull cs:~openstack-charmers-next/percona-cluster $distro/percona-cluster
#charm pull cs:~openstack-charmers-next/neutron-api $distro/neutron-api
#charm pull cs:~openstack-charmers-next/neutron-gateway $distro/neutron-gateway
#charm pull cs:~openstack-charmers-next/neutron-openvswitch $distro/neutron-openvswitch
#charm pull cs:~openstack-charmers-next/nova-cloud-controller $distro/nova-cloud-controller
#charm pull cs:~openstack-charmers-next/nova-compute $distro/nova-compute
#charm pull cs:~openstack-charmers-next/openstack-dashboard $distro/openstack-dashboard
#charm pull cs:~openstack-charmers-next/rabbitmq-server $distro/rabbitmq-server
#charm pull cs:~openstack-charmers-next/heat $distro/heat
#charm pull cs:~openstack-charmers-next/lxd xenial/lxd
