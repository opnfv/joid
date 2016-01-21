=======================
Deploy JOID in your LAB
=======================

Bare Metal Installations:
^^^^^^^^^^^^^^^^^^^^^^^^^
Requirements as per Pharos:
^^^^^^^^^^^^^^^^^^^^^^^^^^^
Networking:
^^^^^^^^^^^
**minimum 2 networks**

| ``1. First for Admin network with gateway to access external network``
| ``2. Second for public network to consume by tenants for floating ips``

**NOTE: JOID support multiple isolated networks for data as well as storage.
Based on your network options for Openstack.**

Minimum 6 physical servers.
~~~~~~~~~~~~~~~~~~~~~~~~~~~
1. Jump Host server:
~~~~~~~~~~~~~~~~~~~~

| ``   Minimum H/W Spec needed``
| ``  CPU cores: 16``
| ``  Memory: 32 GB``
| ``  Hard Disk: 1(250 GB)``
| ``  NIC: eth0(Admin, Management), eth1 (external network)``

2. Control Node Servers (minimum 3):
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

| ``  Minimum H/W Spec``
| ``  CPU cores: 16``
| ``  Memory: 32 GB``
| ``  Hard Disk: 1(500 GB)``
| ``  NIC: eth0(Admin, Management), eth1 (external network)``

3. Compute Node Servers (minimum 2):
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

| ``  Minimum H/W Spec``
| ``  CPU cores: 16``
| ``  Memory: 32 GB``
| ``  Hard Disk: 1(1 TB) this includes the space for ceph as well``
| ``  NIC: eth0(Admin, Management), eth1 (external network)``

**NOTE: Above configuration is minimum and for better performance and usage of
the Openstack please consider higher spec for each nodes.**

Make sure all servers are connected to top of rack switch and configured accordingly. No DHCP server should be up and configured. Only gateway at eth0 and eth1 network should be configure to access the network outside your lab.

Jump Node configuration:
~~~~~~~~~~~~~~~~~~~~~~~~

1. Install Ubuntu 14.04 LTS server version of OS on the nodes.
2. Install the git and bridge-utils packages on the server and configure minimum two bridges on jump host:

brAdm and brPublic cat /etc/network/interfaces

| ``   # The loopback network interface``
| ``   auto lo``
| ``   iface lo inet loopback``
| ``   iface eth0 inet manual``
| ``   auto brAdm ``
| ``   iface brAdm inet static``
| ``       address 10.4.1.1``
| ``       netmask 255.255.248.0``
| ``       network 10.4.0.0``
| ``       broadcast 10.4.7.255``
| ``       gateway 10.4.0.1``
| ``       # dns-* options are implemented by the resolvconf package, if installed``
| ``       dns-nameservers 10.4.0.2``
| ``       bridge_ports eth0``
| ``   auto brPublic``
| ``   iface brPublic inet static``
| ``       address 10.2.66.2``
| ``       netmask 255.255.255.0``
| ``       bridge_ports eth2``

**NOTE: If you choose to use the separate network for management, data and
storage then you need to create bridge for each interface. In case of VLAN tags
use the appropriate network on jump-host depend upon VLAN ID on the interface.**


Configure JOID for your lab
^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Get the joid code from gerritt**

*git clone https://gerrit.opnfv.org/gerrit/p/joid.git*

*cd joid/ci*

**Enable MAAS**

- Create a directory in maas/<company name>/<pod number>/ for example

*mkdir maas/intel/pod7/*


- Copy files from pod5 to pod7

*cp maas/intel/pod5/\* maas/intel/pod7/*

4 files will get copied: deployment.yaml environments.yaml
interfaces.host lxc-add-more-interfaces

deployment.yaml file
^^^^^^^^^^^^^^^^^^^^

Prerequisite:
~~~~~~~~~~~~~


modify deployment.yaml
^^^^^^^^^^^^^^^^^^^^^^

This file has been used to configure your maas and bootstrap node in a
VM. Comments in the file are self explanatory and we expect fill up the
information according to match lab infrastructure information. Sample
deployment.yaml can be found at
https://gerrit.opnfv.org/gerrit/gitweb?p=joid.git;a=blob;f=ci/maas/intel/pod5/deployment.yaml

modify joid/ci/01-deploybundle.sh
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

under section case $3 add the intelpod7 section and make sure you have
information provided correctly. Before example consider your network has
192.168.1.0/24 your default network. and eth1 is on public network which
will be used to assign the floating ip.

| ``    'intelpod7' )``
| ``       # As per your lab vip address list be deafult uses 10.4.1.11 - 10.4.1.20``
| ``        sed -i -- 's/10.4.1.1/192.168.1.2/g' ./bundles.yaml``
| ``       # Choose the external port to go out from gateway to use.``
| ``        sed -i -- 's/#        "ext-port": "eth1"/        "ext-port": "eth1"/g' ./bundles.yaml``
| ``       ;;``

NOTE: If you are using seprate data network then add this line below
also along with other changes. which represents network 10.4.9.0/24 will
be used for data network for openstack

``        sed -i -- 's/#os-data-network: 10.4.8.0\/21/os-data-network: 10.4.9.0\/24/g' ./bundles.yaml``

modify joid/ci/02-maasdeploy.sh
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

under section case $1 add the intelpod7 section and make sure you have
information provided correctly.

| ``     'intelpod7' )``
| ``       cp maas/intel/pod7/deployment.yaml ./deployment.yaml``
| ``       ;;``

NOTE: If you are using VLAN tags or more network for data and storage
then make sure you modify the case $1 section under Enable vlan
interface with maas appropriately. In the example below eth2 has been
used as separate data network for tenants in openstack with network
10.4.9.0/24 on compute and control nodes.

| ``   'intelpod7' )``
| ``       maas refresh``
| ``       enableautomodebyname eth2 AUTO "10.4.9.0/24" compute || true``
| ``       enableautomodebyname eth2 AUTO "10.4.9.0/24" control || true``
| ``       ;;``

Deployment of OPNFV using JOID:
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Once you have done the change in above section then run the following
commands to do the automatic deployments.

MAAS Install
~~~~~~~~~~~~

After integrating the changes as mentioned above run the MAAS install.
Suppose you name the integration lab as intelpod7 then run the below
commands to start the MAAS deployment.

``   ./02-maasdeploy.sh intelpod7``

OPNFV Install
~~~~~~~~~~~~~

| ``   ./deploy.sh -o liberty -s odl -t ha -l intelpod7 -f none``
| ``   ``

NOTE: Possible options are as follows:

| ``   choose which sdn controller to use.``
| ``     [-s ``\ \ ``]``
| ``     nosdn: openvswitch only and no other SDN.``
| ``     odl: OpenDayLight Lithium version.``
| ``     opencontrail: OpenContrail SDN can be installed with Juno Openstack today.``
| ``     onos: ONOS framework as SDN.``
| ``     ``
| ``     [-t ``\ \ ``] ``
| ``     nonha: NO HA mode of Openstack``
| ``     ha: HA mode of openstack.``
| ``     [-o ``\ \ ``]``
| ``     juno: Juno Openstack``
| ``     liberty: Liberty version of openstack.``
| ``     [-l ``\ \ ``] etc...``
| ``     default: For virtual deployment where installation will be done on KVM created using ./02-maasdeploy.sh``
| ``     intelpod5: Install on bare metal OPNFV pod5 of Intel lab.``
| ``     intelpod6``
| ``     orangepod2``
| ``     ..``
| ``     ..``
| ``     ``\ \ ``: if you make changes as per your pod above then please use that.``
| ``     [-f ``\ \ ``]``
| ``     none: no special feature will be enabled.``
| ``     ipv6: ipv6 will be enabled for tenant in openstack.``
| ``     ``

Troubleshoot
~~~~~~~~~~~~

By default debug is enabled in script and error messages will be printed
on ssh terminal where you are running the scripts.

To access of any control or compute nodes. juju ssh for example to login
into openstack-dashboard container.

| ``   juju ssh openstack-dashboard/0 ``
| ``   juju ssh nova-compute/0``
| ``   juju ssh neutron-gateway/0``

By default juju will add the Ubuntu user keys for authentication into
the deployed server and only ssh access will be available.
