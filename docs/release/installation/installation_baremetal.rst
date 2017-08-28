.. highlight:: bash


Bare Metal Installation
=======================
Before proceeding, make sure that your hardware infrastructure satisfies the
:ref:`setup-requirements`.


Networking
----------
Make sure you have at least two networks configured:

1.  *Admin* (management) network with gateway to access the Internet (for
    downloading installation resources).
2.  A *public/floating* network to consume by tenants for floating IPs.

You may configure other networks, e.g. for data or storage, based on your
network options for Openstack.


.. _jumphost-install-os:

Jumphost installation and configuration
---------------------------------------

1.  Install Ubuntu 16.04 (Xenial) LTS server on Jumphost (one of the physical
    nodes).

    .. tip::
        Use ``ubuntu`` as username as password, as this matches the MAAS
        credentials installed later.

        During the OS installation, install the OpenSSH server package to
        allow SSH connections to the Jumphost.

        If the data size of the image is too big or slow (e.g. when mounted
        through a slow virtual console), you can also use the Ubuntu mini ISO.
        Install packages: standard system utilities, basic Ubuntu server,
        OpenSSH server, Virtual Machine host.

        If you have issues with blank console after booting, see
        `this SO answer <https://askubuntu.com/a/38782>`_ and set
        ``nomodeset``, (removing ``quiet splash`` can also be useful to see log
        during booting) either through console in recovery mode or via SSH (if
        installed).

2.  Install git and bridge-utils packages

    ::

       sudo apt install git bridge-utils

3.  Configure bridges for each network to be used.

    Example ``/etc/network/interfaces`` file:

    ::

        source /etc/network/interfaces.d/*

        # The loopback network interface (set by Ubuntu)
        auto lo
        iface lo inet loopback

        # Admin network interface
        iface eth0 inet manual
        auto brAdmin
        iface brAdmin inet static
                bridge_ports eth0
                address 10.5.1.1
                netmask 255.255.255.0

        # Ext. network for floating IPs
        iface eth1 inet manual
        auto brExt
        iface brExt inet static
                bridge_ports eth1
                address 10.5.15.1
                netmask 255.255.255.0

    ..

    .. note::
        If you choose to use the separate network for management, public, data
        and storage, then you need to create bridge for each interface. In case
        of VLAN tags, use the appropriate network on Jumphost depending on the
        VLAN ID on the interface.

    .. note::
        Both of the networks need to have Internet connectivity. If only one
        of your interfaces has Internet access, you can setup IP forwarding.
        For an example how to accomplish that, see the script in Nokia pod 1
        deployment (``labconfig/nokia/pod1/setup_ip_forwarding.sh``).


Configure JOID for your lab
---------------------------

All configuration for the JOID deployment is specified in a ``labconfig.yaml``
file. Here you describe all your physical nodes, their roles in OpenStack,
their network interfaces, IPMI parameters etc. It's also where you configure
your OPNFV deployment and MAAS networks/spaces.
You can find example configuration files from already existing nodes in the
`repository <https://gerrit.opnfv.org/gerrit/gitweb?p=joid.git;a=tree;f=labconfig>`_.

First of all, download JOID to your Jumphost. We recommend doing this in your
home directory.

::

      git clone https://gerrit.opnfv.org/gerrit/p/joid.git

.. tip::
    You can select the stable version of your choice by specifying the git
    branch, for example:

    ::

        git clone -b stable/danube https://gerrit.opnfv.org/gerrit/p/joid.git

Create a directory in ``joid/labconfig/<company_name>/<pod_number>/`` and
create or copy a ``labconfig.yaml`` configuration file to that directory.
For example:

::

    # All JOID actions are done from the joid/ci directory
    cd joid/ci
    mkdir -p ../labconfig/your_company/pod1
    cp ../labconfig/nokia/pod1/labconfig.yaml ../labconfig/your_company/pod1/

Example ``labconfig.yaml`` configuration file:

::

    lab:
      location: your_company
      racks:
      - rack: pod1
        nodes:
        - name: rack-1-m1
          architecture: x86_64
          roles: [network,control]
          nics:
          - ifname: eth0
            spaces: [admin]
            mac: ["12:34:56:78:9a:bc"]
          - ifname: eth1
            spaces: [floating]
            mac: ["12:34:56:78:9a:bd"]
          power:
            type: ipmi
            address: 192.168.10.101
            user: admin
            pass: admin
        - name: rack-1-m2
          architecture: x86_64
          roles: [compute,control,storage]
          nics:
          - ifname: eth0
            spaces: [admin]
            mac: ["23:45:67:89:ab:cd"]
          - ifname: eth1
            spaces: [floating]
            mac: ["23:45:67:89:ab:ce"]
          power:
            type: ipmi
            address: 192.168.10.102
            user: admin
            pass: admin
        - name: rack-1-m3
          architecture: x86_64
          roles: [compute,control,storage]
          nics:
          - ifname: eth0
            spaces: [admin]
            mac: ["34:56:78:9a:bc:de"]
          - ifname: eth1
            spaces: [floating]
            mac: ["34:56:78:9a:bc:df"]
          power:
            type: ipmi
            address: 192.168.10.103
            user: admin
            pass: admin
        - name: rack-1-m4
          architecture: x86_64
          roles: [compute,storage]
          nics:
          - ifname: eth0
            spaces: [admin]
            mac: ["45:67:89:ab:cd:ef"]
          - ifname: eth1
            spaces: [floating]
            mac: ["45:67:89:ab:ce:f0"]
          power:
            type: ipmi
            address: 192.168.10.104
            user: admin
            pass: admin
        - name: rack-1-m5
          architecture: x86_64
          roles: [compute,storage]
          nics:
          - ifname: eth0
            spaces: [admin]
            mac: ["56:78:9a:bc:de:f0"]
          - ifname: eth1
            spaces: [floating]
            mac: ["56:78:9a:bc:df:f1"]
          power:
            type: ipmi
            address: 192.168.10.105
            user: admin
            pass: admin
        floating-ip-range: 10.5.15.6,10.5.15.250,10.5.15.254,10.5.15.0/24
        ext-port: "eth1"
        dns: 8.8.8.8
    opnfv:
        release: d
        distro: xenial
        type: noha
        openstack: ocata
        sdncontroller:
        - type: nosdn
        storage:
        - type: ceph
          disk: /dev/sdb
        feature: odl_l2
        spaces:
        - type: admin
          bridge: brAdmin
          cidr: 10.5.1.0/24
          gateway:
          vlan:
        - type: floating
          bridge: brExt
          cidr: 10.5.15.0/24
          gateway: 10.5.15.1
          vlan:

.. TODO: Details about the labconfig.yaml file

Once you have prepared the configuration file, you may begin with the automatic
MAAS deployment.

MAAS Install
------------

This section will guide you through the MAAS deployment. This is the first of
two JOID deployment steps.

.. note::
    For all the commands in this document, please do not use a ``root`` user
    account to run but instead use a non-root user account. We recommend using
    the ``ubuntu`` user as described above.

    If you have already enabled maas for your environment and installed it then
    there is no need to enabled it again or install it. If you have patches
    from previous MAAS install, then you can apply them here.

    Pre-installed MAAS without using the ``03-maasdeploy.sh`` script is not
    supported. We strongly suggest to use ``03-maasdeploy.sh`` script to deploy
    the MAAS and JuJu environment.

With the ``labconfig.yaml`` configuration file ready, you can start the MAAS
deployment. In the joid/ci directory, run the following command:

::

    # in joid/ci directory
    ./03-maasdeploy.sh custom <absolute path of config>/labconfig.yaml

..

If you prefer, you can also host your ``labconfig.yaml`` file remotely and JOID
will download it from there. Just run

::

    # in joid/ci directory
    ./03-maasdeploy.sh custom http://<web_site_location>/labconfig.yaml

..

This step will take approximately 30 minutes to a couple of hours depending on
your environment.
This script will do the following:

*   If this is your first time running this script, it will download all the
    required packages.
*   Install MAAS on the Jumphost.
*   Configure MAAS to enlist and commission a VM for Juju bootstrap node.
*   Configure MAAS to enlist and commission bare metal servers.
*   Download and load Ubuntu server images to be used by MAAS.

Already during deployment, once MAAS is installed, configured and launched,
you can visit the MAAS Web UI and observe the progress of the deployment.
Simply open the IP of your jumphost in a web browser and navigate to the
``/MAAS`` directory (e.g. ``http://10.5.1.1/MAAS`` in our example). You can
login with username ``ubuntu`` and password ``ubuntu``. In the *Nodes* page,
you can see the bootstrap node and the bare metal servers and their status.

.. hint::
    If you need to re-run this step, first undo the performed actions by
    running

    ::

        # in joid/ci
        ./cleanvm.sh
        ./cleanmaas.sh
        # now you can run the ./03-maasdeploy.sh script again

    ..


Juju Install
------------

This section will guide you through the Juju an OPNFV deployment. This is the
second of two JOID deployment steps.

JOID allows you to deploy different combinations of OpenStack and SDN solutions
in HA or no-HA mode. For OpenStack, it supports Newton and Ocata. For SDN, it
supports Open vSwitch, OpenContrail, OpenDaylight and ONOS (Open Network
Operating System). In addition to HA or no-HA mode, it also supports deploying
the latest from the development tree (tip).

To deploy OPNFV on the previously deployed MAAS system, use the ``deploy.sh``
script. For example:

::

    # in joid/ci directory
    ./deploy.sh -d xenial -m openstack -o ocata -s nosdn -f none -t noha -l custom

The above command starts an OPNFV deployment with Ubuntu Xenial (16.04) distro,
OpenStack model, Ocata version of OpenStack, Open vSwitch (and no other SDN),
no special features, no-HA OpenStack mode and with custom labconfig. I.e. this
corresponds to the ``os-nosdn-nofeature-noha`` OPNFV deployment scenario.

.. note::
    You can see the usage info of the script by running

    ::

        ./deploy.sh --help

    Possible script arguments are as follows.

    **Ubuntu distro to deploy**
    ::

        [-d <trusty|xenial>]

    -   ``trusty``: Ubuntu 16.04.
    -   ``xenial``: Ubuntu 17.04.

    **Model to deploy**
    ::

        [-m <openstack|kubernetes>]

    JOID introduces two various models to deploy.

    -   ``openstack``:  Openstack, which will be used for KVM/LXD
        container-based workloads.
    -   ``kubernetes``: Kubernetes model will be used for docker-based
        workloads.

    **Version of Openstack deployed**
    ::

        [-o <newton|mitaka>]

    -   ``newton``: Newton version of OpenStack.
    -   ``ocata``:  Ocata version of OpenStack.

    **SDN controller**
    ::

        [-s <nosdn|odl|opencontrail|onos>]

    -   ``nosdn``:        Open vSwitch only and no other SDN.
    -   ``odl``:          OpenDayLight Boron version.
    -   ``opencontrail``: OpenContrail SDN.
    -   ``onos``:         ONOS framework as SDN.

    **Feature to deploy** (comma separated list)
    ::

        [-f <lxd|dvr|sfc|dpdk|ipv6|none>]

    -   ``none``: No special feature will be enabled.
    -   ``ipv6``: IPv6 will be enabled for tenant in OpenStack.
    -   ``lxd``:  With this feature hypervisor will be LXD rather than KVM.
    -   ``dvr``:  Will enable distributed virtual routing.
    -   ``dpdk``: Will enable DPDK feature.
    -   ``sfc``:  Will enable sfc feature only supported with ONOS deployment.
    -   ``lb``:   Load balancing in case of Kubernetes will be enabled.

    **Mode of Openstack deployed**
    ::

        [-t <noha|ha|tip>]

    -   ``noha``: No High Availability.
    -   ``ha``:   High Availability.
    -   ``tip``:  The latest from the development tree.

    **Where to deploy**
    ::

        [-l <custom|default|...>]

    -   ``custom``: For bare metal deployment where labconfig.yaml was provided
        externally and not part of JOID package.
    -   ``default``: For virtual deployment where installation will be done on
        KVM created using ``03-maasdeploy.sh``.

    **Architecture**
    ::

        [-a <amd64|ppc64el|aarch64>]

    -   ``amd64``: Only x86 architecture will be used. Future version will
        support arm64 as well.

This step may take up to a couple of hours, depending on your configuration,
internet connectivity etc. You can check the status of the deployment by
running this command in another terminal:

::

    watch juju status --format tabular


.. hint::
    If you need to re-run this step, first undo the performed actions by
    running
    ::

        # in joid/ci
        ./clean.sh
        # now you can run the ./deploy.sh script again

    ..


OPNFV Scenarios in JOID
-----------------------
Following OPNFV scenarios can be deployed using JOID. Separate yaml bundle will
be created to deploy the individual scenario.

======================= ======= ===============================================
Scenario                Owner   Known Issues
======================= ======= ===============================================
os-nosdn-nofeature-ha   Joid
os-nosdn-nofeature-noha Joid
os-odl_l2-nofeature-ha  Joid    Floating ips are not working on this deployment.
os-nosdn-lxd-ha         Joid    Yardstick team is working to support.
os-nosdn-lxd-noha       Joid    Yardstick team is working to support.
os-onos-nofeature-ha    ONOSFW
os-onos-sfc-ha          ONOSFW
k8-nosdn-nofeature-noha Joid    No support from Functest and Yardstick
k8-nosdn-lb-noha        Joid    No support from Functest and Yardstick
======================= ======= ===============================================


.. _troubleshooting:

Troubleshoot
------------
By default debug is enabled in script and error messages will be printed on ssh
terminal where you are running the scripts.

Logs are indispensable when it comes time to troubleshoot. If you want to see
all the service unit deployment logs, you can run ``juju debug-log`` in another
terminal. The debug-log command shows the consolidated logs of all Juju agents
(machine and unit logs) running in the environment.

To view a single service unit deployment log, use ``juju ssh`` to access to the
deployed unit. For example to login into ``nova-compute`` unit and look for
``/var/log/juju/unit-nova-compute-0.log`` for more info:

::

  ubuntu@R4N4B1:~$ juju ssh nova-compute/0
  Warning: Permanently added '172.16.50.60' (ECDSA) to the list of known hosts.
  Warning: Permanently added '3-r4n3b1-compute.maas' (ECDSA) to the list of known hosts.
  Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 3.13.0-77-generic x86_64)

  * Documentation:  https://help.ubuntu.com/
  <skipped>
  Last login: Tue Feb  2 21:23:56 2016 from bootstrap.maas
  ubuntu@3-R4N3B1-compute:~$ sudo -i
  root@3-R4N3B1-compute:~# cd /var/log/juju/
  root@3-R4N3B1-compute:/var/log/juju# ls
  machine-2.log  unit-ceilometer-agent-0.log  unit-ceph-osd-0.log  unit-neutron-contrail-0.log  unit-nodes-compute-0.log  unit-nova-compute-0.log  unit-ntp-0.log
  root@3-R4N3B1-compute:/var/log/juju#

.. note::
    By default Juju will add the Ubuntu user keys for authentication into the
    deployed server and only ssh access will be available.

Once you resolve the error, go back to the jump host to rerun the charm hook
with

::

  $ juju resolved --retry <unit>

If you would like to start over, run
``juju destroy-environment <environment name>`` to release the resources, then
you can run ``deploy.sh`` again.

To access of any of the nodes or containers, use

::

    juju ssh <service name>/<instance id>

For example:

::

    juju ssh openstack-dashboard/0
    juju ssh nova-compute/0
    juju ssh neutron-gateway/0

You can see the available nodes and containers by running

::

    juju status

All charm log files are available under ``/var/log/juju``.

-----

If you have questions, you can join the JOID channel ``#opnfv-joid`` on
`Freenode <https://webchat.freenode.net/>`_.


Common Issues
-------------

The following are the common issues we have collected from the community:

-   The right variables are not passed as part of the deployment procedure.

    ::

        ./deploy.sh -o newton -s nosdn -t ha -l custom -f none

-   If you have not setup MAAS with ``03-maasdeploy.sh`` then the
    ``./clean.sh`` command could hang, the ``juju status`` command may hang
    because the correct MAAS API keys are not mentioned in cloud listing for
    MAAS.

    _Solution_: Please make sure you have an MAAS cloud listed using juju
    clouds and the correct MAAS API key has been added.
-   Deployment times out: use the command ``juju status`` and make sure all
    service containers receive an IP address and they are executing code.
    Ensure there is no service in the error state.
-   In case the cleanup process hangs,run the juju destroy-model command
    manually.

**Direct console access** via the OpenStack GUI can be quite helpful if you
need to login to a VM but cannot get to it over the network.
It can be enabled by setting the ``console-access-protocol`` in the
``nova-cloud-controller`` to ``vnc``. One option is to directly edit the
``juju-deployer`` bundle and set it there prior to deploying OpenStack.

::

    nova-cloud-controller:
      options:
        console-access-protocol: vnc

To access the console, just click on the instance in the OpenStack GUI and
select the Console tab.



.. Links:
.. _`Ubuntu download`: https://www.ubuntu.com/download/server
