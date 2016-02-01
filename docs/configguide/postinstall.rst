JOID post installation procedures
=================================

Configure OpenStack
-------------------
In each SDN directory, for example joid/ci/opencontrail, there is a folder
for Juju deployer where you can find the charm bundle yaml files that the
deploy.sh uses to deploy.

In the same directory, there is **scripts** folder where you can find shell
scripts to help you configure the OpenStack cloud that you just deployed. These
scripts are created to help you configure a basic OpenStack Cloud to verify
the cloud. For more info on OpenStack Cloud configuration, please refer to the
OpenStack Cloud Administrator Guide on docs.openstack.org. Similarly, for
complete SDN configuration, please refer to the respective SDN adminstrator guide.

Each SDN solution requires slightly different setup, please refer to the **README**
in each SDN folder. Most likely you will need to modify the **openstack.sh**
and **cloud-setup.sh** scripts for the floating IP range, private IP network,
and SSH keys. Please go through **openstack.sh**, **glance.sh** and
**cloud-setup.sh** and make changes as you see fit.


