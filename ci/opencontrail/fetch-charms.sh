#!/bin/sh -ex

mkdir -p src/charms/trusty src/charms/precise

# openstack
bzr branch lp:~openstack-charmers/charms/trusty/glance/next src/charms/trusty/glance-next
bzr branch lp:~openstack-charmers/charms/trusty/keystone/next src/charms/trusty/keystone-next
bzr branch lp:~openstack-charmers/charms/trusty/neutron-api/vpp src/charms/trusty/neutron-api-vpp
bzr branch lp:~openstack-charmers/charms/trusty/nova-cloud-controller/next src/charms/trusty/nova-cloud-controller-next
bzr branch lp:~openstack-charmers/charms/trusty/nova-compute/next src/charms/trusty/nova-compute-next
bzr branch lp:~openstack-charmers/charms/trusty/openstack-dashboard/next src/charms/trusty/openstack-dashboard-next
bzr branch lp:~sdn-charmers/charms/trusty/quantum-gateway/contrail src/charms/trusty/quantum-gateway-contrail

# contrail
bzr branch lp:~sdn-charmers/charms/precise/cassandra/forced-install src/charms/precise/cassandra-forced-install
bzr branch lp:~sdn-charmers/charms/trusty/contrail-analytics/trunk src/charms/trusty/contrail-analytics
bzr branch lp:~sdn-charmers/charms/trusty/contrail-configuration/trunk src/charms/trusty/contrail-configuration
bzr branch lp:~sdn-charmers/charms/trusty/contrail-control/trunk src/charms/trusty/contrail-control
bzr branch lp:~sdn-charmers/charms/trusty/contrail-webui/trunk src/charms/trusty/contrail-webui
bzr branch lp:~sdn-charmers/charms/trusty/neutron-api-contrail/trunk src/charms/trusty/neutron-api-contrail
bzr branch lp:~sdn-charmers/charms/trusty/neutron-contrail/trunk src/charms/trusty/neutron-contrail
bzr branch lp:~sdn-charmers/charms/precise/zookeeper/fix-symlink src/charms/precise/zookeeper-fix-symlink

mkdir -p charms/trusty charms/precise
(cd charms/trusty; ln -s ../../src/charms/trusty/* .)
# symlink trusty charms to precise
(cd charms/precise; ln -s ../../src/charms/trusty/* .; ln -s ../../src/charms/precise/* .)
