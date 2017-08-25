.. highlight:: bash


Virtual Installation
=======================

The virtual deployment of JOID is very simple and does not require any special
configuration. To deploy a virtual JOID environment follow these few simple
steps:

1.  Install a clean Ubuntu 16.04 (Xenial) server on the machine. You can use
    the tips noted in the first step of the :ref:`jumphost-install-os` for
    bare metal deployment. However, no specialized configuration is needed,
    just make sure you have Internet connectivity.

2.  Run the MAAS deployment for virtual deployment without customized labconfig
    file:

    ::

        # in joid/ci directory
        ./03-maasdeploy.sh

3.  Run the Juju/OPNFV deployment with your desired configuration parameters,
    but with ``-l default -i 1`` for virtual deployment. For example to deploy
    the Kubernetes model:

    ::

        # in joid/ci directory
        ./deploy.sh -d xenial -s nosdn -t noha -f none -m kubernetes -l default -i 1

    ..

Now you should have a working JOID deployment with three virtual nodes. In case
of any issues, refer to the :ref:`troubleshooting` section.
