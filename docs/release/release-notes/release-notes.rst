.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>


Abstract
========

This document compiles the release notes for the Danube release of
OPNFV when using JOID as a deployment tool.

Introduction
============

These notes provides release information for the use of joid as deployment
tool for the Danube release of OPNFV.

The goal of the Danube release and this JOID based deployment process is
to establish a lab ready platform accelerating further development
of the OPNFV infrastructure.

Carefully follow the installation-instructions which guides a user to deploy
OPNFV using JOID which is based on MAAS and Juju.

Summary
=======

The Danube release with the JOID deployment toolchain will establish an OPNFV target system on a Pharos compliant lab infrastructure.
The current definition of an OPNFV target system is and OpenStack Newton combined with OpenDaylight Boron.

The system is deployed with OpenStack High Availability (HA) for most OpenStack services.
Ceph storage is used as Cinder backend, and is the only supported storage for Danube. Ceph is setup as 3 OSDs and 3 Monitors, one radosgw.

    User has following choices to make to do the deployment.

    - Openstack      -- Newton
    - Type           -- HA, nonHA, tip (stable git branch of respective openstack)
    - SDN controller -- OpenDaylight, nosdn(Openvswitch), Onos, OpenContrail
    - Feature        -- IPV6, DVR(distributed virtual routing), SFC(service function chaining odl only), BGPVPN(odl only), LB(Load Balancer for Kubernetes)
    - Distro         -- Xenial
    - Model          -- Openstack, Kubernetes

- Documentation is built by Jenkins
- Jenkins deploys a Denbue release with the JOID deployment toolchain baremetal,
  which includes 3 control+network nodes, and 2 compute nodes.

NOTE: Detailed information on how to install in your lab can be find in installation guide

Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | JOID                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | gerrit.opnfv.org/gerrit/joid.git     |
|                                      | stable/danube                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Denbue release                     |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | March 31 2017                      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | Danube release                     |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Deliverables
------------

Software deliverables
~~~~~~~~~~~~~~~~~~~~~
`JOID based installer script files <https://gerrit.opnfv.org/gerrit/gitweb?p=joid.git;a=summary>`_

Documentation deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~

- Installation instructions
- Release notes (This document)
- User guide

Version change
--------------
.. This section describes the changes made since the last version of this document.

Module version change
~~~~~~~~~~~~~~~~~~~~~
  - Danube release with the JOID deployment toolchain.
  - OpenStack (Newton release)
  - OpenDaylight (Boron release)
  - Ubuntu 16.04 LTS

Document version change
~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for the Danube release using JOID deployment
  toolchain - ver. 1.0.0
- OPNFV Release Notes with the JOID deployment toolchain - ver. 1.0.0 (this document)

Reason for new version
----------------------

Feature additions
~~~~~~~~~~~~~~~~~

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
+--------------------------------------+--------------------------------------+
| JIRA: JOID-1                         | use Juju and Ubuntu to deploy OPNFV  |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-103                       | OpenDaylight Carbon Support          |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-100                       | MAAS 2.x support                     |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-101                       | Juju 2.x support                     |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-99                        | jumphost support for 16.04           |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-106                       | Kubernetes on Baremetal              |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-108                       | integrate load balancer              |
| 		                       | Kubernetes on Baremetal              |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-110                       | Enable VM console in Horizon         |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-102                       | Enable OpenStack Newton              |
+--------------------------------------+--------------------------------------+

Bug corrections
~~~~~~~~~~~~~~~

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA:                                |                                      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+


Known Limitations, Issues and Workarounds
=========================================

System Limitations
------------------
**Min jumphost requirements:** At least 16GB of RAM, 4 core cpu and 250 gb disk should support virtualization.


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
| JIRA:                                | floating ip are not working for ODL. |
+--------------------------------------+--------------------------------------+
| JIRA:                                | No functest and yardstick support.   |
+--------------------------------------+--------------------------------------+


Workarounds
-----------
See JIRA: <link>


Test Result
===========
Danube test result using JOID as deployment tool.
- `https://build.opnfv.org/ci/view/joid/job/functest-joid-baremetal-daily-colorado/>`_
- `https://build.opnfv.org/ci/view/joid/job/yardstick-joid-baremetal-daily-colorado/>`_

Scenario Releases
=================
Name:      joid-os-nosdn-nofeature-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-nofeature-ha-baremetal-daily-colorado/
Notes:

Name:      joid-os-odl-nofeature-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-odl_l2-nofeature-ha-baremetal-daily-colorado/
Notes:

Name:      joid-os-nosdn-lxd-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-lxd-ha-baremetal-daily-colorado/
Notes:

Name:      joid-os-onos-nofeature-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-onos-nofeature-ha-baremetal-daily-colorado/
Notes:

Name:      joid-os-onos-sfc-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-onos-sfc-ha-baremetal-daily-colorado/
Notes:

Name:      joid-os-nosdn-lxd-noha
Test Link: https://build.opnfv.org/ci/user/narindergupta/my-views/view/joid/job/joid-os-nosdn-lxd-noha-baremetal-daily-colorado/
Notes:

Name:      joid-os-nosdn-nofeature-noha
Test Link: https://build.opnfv.org/ci/user/narindergupta/my-views/view/joid/job/joid-os-nosdn-nofeature-noha-baremetal-daily-colorado/
Notes:

Name:      joid-k8-nosdn-nofeature-noha
Test Link: https://build.opnfv.org/ci/user/narindergupta/my-views/view/joid/job/joid-deploy-baremetal-daily-master/1833/console/
Notes:

Name:      joid-k8-nosdn-lb-noha
Test Link: https://build.opnfv.org/ci/user/narindergupta/my-views/view/joid/job/joid-os-nosdn-nofeature-noha-baremetal-daily-colorado/
Notes:

References
==========
For more information on the OPNFV Danube release, please visit
- `OPNFV Danube release <http://www.opnfv.org/danube>`_

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
- `OPNFV JOID User Guide <https://wiki.opnfv.org/joid/b_userguide>`_
- `OPNFV Release Notes <https://wiki.opnfv.org/display/joid/Danube+Release+Notes>`_
- `OPNFV JOID Install Guide <https://wiki.opnfv.org/display/joid/Danube+installation+Guide>`_

OpenStack
---------
- `OpenStack Newton Release artifacts <http://www.openstack.org/software/newton>`_
- `OpenStack documentation <http://docs.openstack.org>`_

OpenDaylight
------------
- `OpenDaylight artifacts <http://www.opendaylight.org/software/downloads>`_

