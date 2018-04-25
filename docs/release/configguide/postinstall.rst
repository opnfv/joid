JOID post installation procedures
=================================

Configure OpenStack
-------------------

openstack.sh under joid/ci used to configure the openstack after deployment

./openstack.sh <nosdn> custom xenial pike

Below commands are used to setup domain in heat.
juju run-action heat/0 domain-setup

Upload cloud images and creates the sample network to test.

joidjuju/get-cloud-images
joid/juju/joid-configure-openstack


Configure Kubernets
-------------------

k8.sh under joid/ci would be used to show the kubernets workload and create
sample pods.

./k8.sh

Juju GUI
--------

Below command would be used to display Juju GUI url along with credentials.

juju gui --show-credentials --no-browser


