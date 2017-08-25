.. _setup-requirements:

Setup Requirements
==================

Network Requirements
--------------------

Minimum 2 Networks:

-   One for the administrative network with gateway to access the Internet
-   One for the OpenStack public network to access OpenStack instances via
    floating IPs

JOID supports multiple isolated networks for data as well as storage based on
your network requirement for OpenStack.

No DHCP server should be up and configured. Configure gateways only on eth0 and
eth1 networks to access the network outside your lab.


Jumphost Requirements
---------------------

The Jumphost requirements are outlined below:

-   OS: Ubuntu 16.04 LTS Server
-   Root access.
-   CPU cores: 16
-   Memory: 32GB
-   Hard Disk: 1× (min. 250 GB)
-   NIC: eth0 (admin, management), eth1 (external connectivity)

Physical nodes requirements (bare metal deployment)
---------------------------------------------------

Besides Jumphost, a minimum of 5 physical servers for bare metal environment.

-   CPU cores: 16
-   Memory: 32GB
-   Hard Disk: 2× (500GB) prefer SSD
-   NIC: eth0 (Admin, Management), eth1 (external network)

**NOTE**: Above configuration is minimum. For better performance and usage of
the OpenStack, please consider higher specs for all nodes.

Make sure all servers are connected to top of rack switch and configured
accordingly.
