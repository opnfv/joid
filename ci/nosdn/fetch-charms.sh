#!/bin/sh -ex

distro=$1
mkdir -p $distro

# openstack
bzr branch lp:~openstack-charmers/charms/trusty/ceilometer/next $distro/ceilometer
bzr branch lp:~openstack-charmers/charms/trusty/ceilometer-agent/next $distro/ceilometer-agent
bzr branch lp:~openstack-charmers/charms/trusty/ceph/next $distro/ceph
bzr branch lp:~openstack-charmers/charms/trusty/ceph-osd/next $distro/ceph-osd
bzr branch lp:~openstack-charmers/charms/trusty/ceph-radosgw/next $distro/ceph-radosgw
bzr branch lp:~openstack-charmers/charms/trusty/cinder/next $distro/cinder
bzr branch lp:~openstack-charmers/charms/trusty/cinder-ceph/next $distro/cinder-ceph
bzr branch lp:~openstack-charmers/charms/trusty/glance/next $distro/glance
bzr branch lp:~narindergupta/charms/trusty/promise/trunk $distro/promise
bzr branch lp:~openstack-charmers/charms/trusty/keystone/next $distro/keystone
bzr branch lp:~openstack-charmers/charms/trusty/percona-cluster/next $distro/percona-cluster
bzr branch lp:~openstack-charmers/charms/trusty/neutron-api/next $distro/neutron-api
bzr branch lp:~openstack-charmers/charms/trusty/neutron-gateway/next $distro/neutron-gateway
bzr branch lp:~openstack-charmers/charms/trusty/neutron-openvswitch/next $distro/neutron-openvswitch
bzr branch lp:~openstack-charmers/charms/trusty/nova-cloud-controller/next $distro/nova-cloud-controller
bzr branch lp:~openstack-charmers/charms/trusty/nova-compute/next $distro/nova-compute
bzr branch lp:~openstack-charmers/charms/trusty/openstack-dashboard/next $distro/openstack-dashboard
bzr branch lp:~openstack-charmers/charms/trusty/rabbitmq-server/next $distro/rabbitmq-server
bzr branch lp:~openstack-charmers/charms/trusty/hacluster/next $distro/hacluster
bzr branch lp:~openstack-charmers/charms/trusty/heat/next $distro/heat
bzr branch lp:~billy-olsen/charms/xenial/mongodb/trunk $distro/mongodb
bzr branck lp:~narindergupta/opnfv/ntp $distro/ntp
