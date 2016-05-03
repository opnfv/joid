#!/bin/sh -ex

distro=trusty
mkdir -p $distro

# openstack
bzr branch lp:~openstack-charmers/charms/$distro/ceilometer/next $distro/ceilometer
bzr branch lp:~openstack-charmers/charms/$distro/ceilometer-agent/next $distro/ceilometer-agent
bzr branch lp:~openstack-charmers/charms/$distro/ceph/next $distro/ceph
bzr branch lp:~openstack-charmers/charms/$distro/ceph-osd/next $distro/ceph-osd
bzr branch lp:~openstack-charmers/charms/$distro/ceph-radosgw/next $distro/ceph-radosgw
bzr branch lp:~openstack-charmers/charms/$distro/cinder/next $distro/cinder
bzr branch lp:~openstack-charmers/charms/$distro/cinder-ceph/next $distro/cinder-ceph
bzr branch lp:~openstack-charmers/charms/$distro/glance/next $distro/glance
bzr branch lp:~narindergupta/charms/$distro/promise/trunk $distro/promise
bzr branch lp:~openstack-charmers/charms/$distro/keystone/next $distro/keystone
bzr branch lp:~openstack-charmers/charms/$distro/percona-cluster/next $distro/percona-cluster
bzr branch lp:~openstack-charmers/charms/$distro/neutron-api/next $distro/neutron-api
bzr branch lp:~openstack-charmers/charms/$distro/neutron-gateway/next $distro/neutron-gateway
bzr branch lp:~openstack-charmers/charms/$distro/neutron-openvswitch/next $distro/neutron-openvswitch
bzr branch lp:~openstack-charmers/charms/$distro/nova-cloud-controller/next $distro/nova-cloud-controller
bzr branch lp:~openstack-charmers/charms/$distro/nova-compute/next $distro/nova-compute
bzr branch lp:~openstack-charmers/charms/$distro/openstack-dashboard/next $distro/openstack-dashboard
bzr branch lp:~openstack-charmers/charms/$distro/rabbitmq-server/next $distro/rabbitmq-server
bzr branch lp:~openstack-charmers/charms/$distro/hacluster/next $distro/hacluster
bzr branch lp:~openstack-charmers/charms/$distro/heat/next $distro/heat
