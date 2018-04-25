Introduction
============

JOID in brief
-------------
JOID as *Juju OPNFV Infrastructure Deployer* allows you to deploy different
combinations of OpenStack release and SDN solution in HA or non-HA mode. For
OpenStack, JOID currently supports Ocata and Pike. For SDN, it supports
Openvswitch, OpenContrail, OpenDayLight, and ONOS. In addition to HA or non-HA
mode, it also supports deploying from the latest development tree.

JOID heavily utilizes the technology developed in Juju and MAAS.

Juju_ is a state-of-the-art, open source modelling tool for operating software
in the cloud. Juju allows you to deploy, configure, manage, maintain, and scale
cloud applications quickly and efficiently on public clouds, as well as on
physical servers, OpenStack, and containers. You can use Juju from the command
line or through its beautiful `GUI <JUJU GUI_>`_.
(source: `Juju Docs <https://jujucharms.com/docs/2.2/about-juju>`_)

MAAS_ is *Metal As A Service*. It lets you treat physical servers like virtual
machines (instances) in the cloud. Rather than having to manage each server
individually, MAAS turns your bare metal into an elastic cloud-like resource.
Machines can be quickly provisioned and then destroyed again as easily as you
can with instances in a public cloud. ... In particular, it is designed to work
especially well with Juju, the service and model management service. It's a
perfect arrangement: MAAS manages the machines and Juju manages the services
running on those machines.
(source: `MAAS Docs <https://docs.ubuntu.com/maas/2.1/en/index>`_)

Typical JOID Architecture
-------------------------
The MAAS server is installed and configured on Jumphost with Ubuntu 16.04 LTS
server with access to the Internet. Another VM is created to be managed by
MAAS as a bootstrap node for Juju. The rest of the resources, bare metal or
virtual, will be registered and provisioned in MAAS. And finally the MAAS
environment details are passed to Juju for use.

.. TODO: setup diagram


.. Links:
.. _Juju: https://jujucharms.com/
.. _`JUJU GUI`: https://jujucharms.com/docs/stable/controllers-gui
.. _MAAS: https://maas.io/
