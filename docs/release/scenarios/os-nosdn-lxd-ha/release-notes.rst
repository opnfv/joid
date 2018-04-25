.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>


Abstract
========

This document compiles the release notes for the Fraser release of
OPNFV when using JOID as a deployment tool with LXD container hypervisor.

Introduction
============

These notes provides release information for the use of joid as deployment
tool for the Fraser release of OPNFV with LXD hypervisor for containers
scenario.

The goal of the Fraser release and this JOID based deployment process is
to establish a lab ready platform accelerating further development
of the OPNFV infrastructure.

Carefully follow the installation-instructions which guides a user to deploy
OPNFV using JOID which is based on MAAS and Juju.

Summary
=======

    LXD is a lightweight container hypervisor for full system containers,
unlike Docker and Rocket which is for application containers. This means that
the container will look and feel like a regular VM – but will act like a
container. LXD uses the same container technology found in the Linux kernel
(cgroups, namespaces, LSM, etc).

Fraser release with the JOID deployment with LXD hypervisor will establish an
OPNFV target system on a Pharos compliant lab infrastructure.
The current definition of an OPNFV target system is and OpenStack Pike combined
with LXD Hypervisor.

    The system is deployed with OpenStack High Availability (HA) for most OpenStack services.

    User has following choices to make to do the deployment.

    - Openstack      -- Pike
    - Type           -- HA, nonHA, tip (stable git branch of respective openstack)
    - Feature        -- LXD (container hypervisor)

NOTE: Detailed information on how to install in your lab can be find in installation guide
command to deploy lxd feature is:

#LXD deployment with HA Openstack
./deploy.sh -o pike -f lxd -t ha -l custom -s nosdn

#LXD deployment with no HA Openstack
./deploy.sh -o pike -f lxd -t noha -l custom -s nosdn

Using LXD with Openstack
========================

Once you have finished installinf the JOID with LXD container hypervisor you can use the
following to uplod your lxd image to the glance server that LXD can use.
In order to do that you simply have to do the following:

wget -O xenial-server-cloudimg-amd64-root.tar.gz \
https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-root.tar.gz

glance image-create --name="Xenial LXC x86_64" --visibility=public --container-format=bare \
--disk-format=root-tar --property architecture="x86_64" xenial-server-cloudimg-amd64-root.tar.gz

After you upload the image to glance then you will be ready to go. If you have any questions
please don’t hesitate to ask on the LXC mailing, #lxcontainers IRC channel on freenode


Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | JOID                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | gerrit.opnfv.org/gerrit/joid.git     |
|                                      | opnfv-6.0.0                          |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Fraser release                       |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | April 27 2018                        |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | Fraser release                       |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Deliverables
------------

Software deliverables
~~~~~~~~~~~~~~~~~~~~~
`JOID based installer script files <https://gerrit.opnfv.org/gerrit/gitweb?p=joid.git;a=summary>`_

Known Limitations, Issues and Workarounds
=========================================

Known issues
------------

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: YARDSTICK-325                  | Provide raw format yardstick vm image|
|                                      | for nova-lxd scenario(OPNFV)         |
+--------------------------------------+--------------------------------------+
| JIRA:                                |                                      |
+--------------------------------------+--------------------------------------+


Scenario Releases
=================
Name:      joid-os-nosdn-lxd-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-lxd-ha-baremetal-daily-fraser/
Notes:

Name:      joid-os-nosdn-lxd-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-lxd-noha-baremetal-daily-fraser/
Notes:

References
==========
LXD
---
- `JUJU LXD charm <https://jujucharms.com/lxd/xenial/2>`_
- `LXD hypervisor <https://help.ubuntu.com/lts/serverguide/lxd.html>`_
- `LXD Story <http://insights.ubuntu.com/2016/03/14/the-lxd-2-0-story-prologue/>`_

Juju
----
- `Juju Charm store <https://jujucharms.com/>`_
- `Juju documents <https://jujucharms.com/docs/stable/getting-started>`_

MAAS
----
- `Bare metal management (Metal-As-A-Service) <http://maas.io/get-started>`_
- `MAAS API documents <http://maas.ubuntu.com/docs/>`_

JOID
----
- `OPNFV JOID wiki <https://wiki.opnfv.org/joid>`_
- `OPNFV JOID Get Started <https://wiki.opnfv.org/display/joid/JOID+Get+Started>`_

OpenStack
---------
- `OpenStack Pike Release artifacts <http://www.openstack.org/software/pike>`_
- `OpenStack documentation <http://docs.openstack.org>`_

