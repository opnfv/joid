.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>


Abstract
========

This document compiles the release notes for the Danube release of
OPNFV when using JOID as a deployment tool with KVM hypervisor.

Introduction
============

These notes provides release information for the use of joid as deployment
tool for the Danube release of OPNFV with KVM hypervisor for containers
scenario.

The goal of the Danube release and this JOID based deployment process is
to establish a lab ready platform accelerating further development
of the OPNFV infrastructure.

Carefully follow the installation-instructions which guides a user to deploy
OPNFV using JOID which is based on MAAS and Juju.

Summary
=======

    KVM (for Kernel-based Virtual Machine) is a full virtualization solution
for Linux on x86 hardware containing virtualization extensions (Intel VT or AMD-V).
It consists of a loadable kernel module, kvm.ko, that provides the core
virtualization infrastructure and a processor specific module, kvm-intel.ko or kvm-amd.ko.

Danube release with the JOID deployment with KVM hypervisor will establish an
OPNFV target system on a Pharos compliant lab infrastructure.

The current definition of an OPNFV target system is and OpenStack Newton.

    The system is deployed with OpenStack High Availability (HA) for most OpenStack services.

    User has following choices to make to do the deployment.

    - Openstack      -- Newton
    - Type           -- HA, nonHA, tip (stable git branch of respective openstack)
    - Feature        -- KVM (hypervisor)

NOTE: Detailed information on how to install in your lab can be find in installation guide
command to deploy lxd feature is:

#KVM deployment with HA Openstack
./deploy.sh -o newton -f none -t ha -l custom -s nosdn

#LXD deployment with no HA Openstack
./deploy.sh -o newton -f none -t noha -l custom -s nosdn

Using Openstack
===============

admin-openrc file have been placed under ~/joid_config/
Please source the same and use OpenStack API to do rest of the configuration.


Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | JOID                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | gerrit.opnfv.org/gerrit/joid.git     |
|                                      | stable/danube                        |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Danube release                       |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | April 01 2017                        |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | Danube release                       |
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
| JIRA:                                |                                      |
+--------------------------------------+--------------------------------------+


Scenario Releases
=================
Name:      joid-os-nosdn-lxd-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-lxd-ha-baremetal-daily-danube/
Notes:

Name:      joid-os-nosdn-lxd-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-lxd-noha-baremetal-daily-danube/
Notes:

References
==========
KVM
---
- `JUJU Openstack charm <https://jujucharms.com/openstack-telemetry/>`_
- `KVM hypervisor <https://help.ubuntu.com/community/KVM/Installation>`_

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
- `OpenStack Newton Release artifacts <http://www.openstack.org/software/newton>`_
- `OpenStack documentation <http://docs.openstack.org>`_

