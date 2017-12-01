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

git clone -b stable/17.08 https://github.com/openstack/charm-hacluster.git $distro/hacluster
git clone -b stable/17.08 https://github.com/openstack/charm-ceilometer.git $distro/ceilometer
git clone -b stable/17.08 https://github.com/openstack/charm-ceilometer-agent.git $distro/ceilometer-agent
git clone -b stable/17.08 https://github.com/openstack/charm-ceph-mon.git $distro/ceph-mon
git clone -b stable/17.08 https://github.com/openstack/charm-ceph-osd.git $distro/ceph-osd
git clone -b stable/17.08 https://github.com/openstack/charm-ceph-radosgw.git $distro/ceph-radosgw
git clone -b stable/17.08 https://github.com/openstack/charm-cinder.git $distro/cinder
git clone -b stable/17.08 https://github.com/openstack/charm-cinder-ceph.git $distro/cinder-ceph
git clone -b stable/17.08 https://github.com/openstack/charm-glance.git $distro/glance
git clone -b stable/17.08 https://github.com/openstack/charm-keystone.git $distro/keystone
git clone -b stable/17.08 https://github.com/openstack/charm-percona-cluster.git $distro/percona-cluster
git clone -b stable/17.08 https://github.com/openstack/charm-neutron-api.git $distro/neutron-api
git clone -b stable/17.08 https://github.com/openstack/charm-neutron-gateway.git $distro/neutron-gateway
git clone -b stable/17.08 https://github.com/openstack/charm-neutron-openvswitch.git $distro/neutron-openvswitch
git clone -b stable/17.08 https://github.com/openstack/charm-nova-cloud-controller.git $distro/nova-cloud-controller
git clone -b stable/17.08 https://github.com/openstack/charm-nova-compute.git $distro/nova-compute
git clone -b stable/17.08 https://github.com/openstack/charm-openstack-dashboard.git $distro/openstack-dashboard
git clone -b stable/17.08 https://github.com/openstack/charm-rabbitmq-server.git $distro/rabbitmq-server
git clone -b stable/17.08 https://github.com/openstack/charm-heat.git $distro/heat
git clone -b stable/17.08 https://github.com/openstack/charm-lxd.git $distro/lxd
git clone -b stable/17.08 https://github.com/openstack/charm-odl-controller.git $distro/odl-controller
git clone -b stable/17.08 https://github.com/openstack/charm-neutron-api-odl.git $distro/neutron-api-odl
git clone -b stable/17.08 https://github.com/openstack/charm-openvswitch-odl.git $distro/openvswitch-odl
git clone https://github.com/openbaton/juju-charm.git $distro/openbaton

charm pull cs:$distro/aodh $distro/aodh
charm pull cs:$distro/mongodb $distro/mongodb
charm pull cs:$distro/ntp $distro/ntp

#pulling scaleio charms.
charm pull cs:~cloudscaling/scaleio-mdm $distro/scaleio-mdm
charm pull cs:~cloudscaling/scaleio-sds $distro/scaleio-sds
charm pull cs:~cloudscaling/scaleio-gw $distro/scaleio-gw
charm pull cs:~cloudscaling/scaleio-sdc $distro/scaleio-sdc
charm pull cs:~cloudscaling/scaleio-openstack $distro/scaleio-openstack
charm pull cs:~cloudscaling/scaleio-cluster $distro/scaleio-cluster
charm pull cs:~cloudscaling/scaleio-gui $distro/scaleio-gui

#odl controller specific charm
#charm pull cs:$distro/odl-controller $distro/odl-controller
#charm pull cs:~narindergupta/neutron-api-odl-11 $distro/neutron-api-odl
#charm pull cs:~narindergupta/openvswitch-odl-3 $distro/openvswitch-odl
#charm pull cs:~narindergupta/neutron-gateway-6 $distro/neutron-gateway
charm pull cs:~narindergupta/congress-1 $distro/congress
