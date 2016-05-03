#!/bin/sh -ex

distro=$distro
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
bzr branch lp:~opnfv-team/charms/$distro/haproxy/trunk $distro/haproxy

# Controller specific charm
bzr branch lp:~sdn-charmers/charms/$distro/keepalived/trunk $distro/keepalived
bzr branch lp:~stub/charms/$distro/cassandra/noauthentication $distro/cassandra-noauthentication
bzr branch lp:~sdn-charmers/charms/$distro/contrail-analytics/trunk $distro/contrail-analytics
bzr branch lp:~sdn-charmers/charms/$distro/contrail-configuration/trunk $distro/contrail-configuration
bzr branch lp:~sdn-charmers/charms/$distro/contrail-control/trunk $distro/contrail-control
bzr branch lp:~sdn-charmers/charms/$distro/contrail-webui/trunk $distro/contrail-webui
bzr branch lp:~charmers/charms/precise/zookeeper/trunk src/charms/precise/zookeeper
bzr branch lp:~opnfv-team/charms/$distro/neutron-api-contrail/trunk $distro/neutron-api-contrail
bzr branch lp:~opnfv-team/charms/$distro/neutron-contrail/trunk $distro/neutron-contrail

