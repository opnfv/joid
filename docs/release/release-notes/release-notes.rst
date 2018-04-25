/. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>


Abstract
========

This document compiles the release notes for the Fraser release of
OPNFV when using JOID as a deployment tool.

Introduction
============

These notes provides release information for the use of joid as deployment
tool for the Fraser release of OPNFV.

The goal of the Fraser release and this JOID based deployment process is
to establish a lab ready platform accelerating further development
of the OPNFV infrastructure.

Carefully follow the installation-instructions which guides a user to deploy
OPNFV using JOID which is based on MAAS and Juju.

Summary
=======

The Fraser release with the JOID deployment toolchain will establish an OPNFV target system on a Pharos compliant lab infrastructure.
The current definition of an OPNFV target system is and OpenStack Pike combined with OpenDaylight Boron.

The system is deployed with OpenStack High Availability (HA) for most OpenStack services.
Ceph storage is used as Cinder backend, and is the only supported storage for Fraser. Ceph is setup as 3 OSDs and 3 Monitors, one radosgw.

    User has following choices to make to do the deployment.

    - Openstack      -- Pike
    - Type           -- HA, nonHA, tip (stable git branch of respective openstack)
    - SDN controller -- nosdn(Openvswitch), Onos, OpenContrail, Canal(k8), OVN (K8)
    - Feature        -- IPV6, DVR(distributed virtual routing), ceph(Kubernetes storage), LB(Load Balancer for Kubernetes)
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
  - Fraser release with the JOID deployment toolchain.
  - OpenStack (Pike release)
  - Kubernetes 1.8
  - Ubuntu 16.04 LTS

Document version change
~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for the Fraser release using JOID deployment
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
| JIRA:	JOID-100                       | MAAS 2.x support                     |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-101                       | Juju 2.x support                     |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-99                        | jumphost support for 16.04           |
+--------------------------------------+--------------------------------------+
| JIRA:	JOID-106                       | Kubernetes on Baremetal              |
+--------------------------------------+--------------------------------------+
| JIRA:	                               | Enable OpenStack Pike               |
+--------------------------------------+--------------------------------------+
|                                      | Enable OpenContrail                  |
+--------------------------------------+--------------------------------------+
|                                      | Enable OVN for Kubernetes            |
+--------------------------------------+--------------------------------------+

Bug corrections
~~~~~~~~~~~~~~~

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA:                                | Fixes the issue on get the keyston IP|
+--------------------------------------+--------------------------------------+
| JIRA:                                | Fix provided where use Public API    |
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
| JIRA:                                | No functest support for Kubernetes.  |
+--------------------------------------+--------------------------------------+


Workarounds
-----------
See JIRA: <link>


Scenario Releases
=================
Name:      joid-os-nosdn-nofeature-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-nofeature-ha-baremetal-daily-fraser/
Notes:

Name:      joid-os-nosdn-lxd-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-lxd-ha-baremetal-daily-fraser/
Notes:

Name:      joid-os-nosdn-lxd-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-lxd-noha-baremetal-daily-fraser/
Notes:

Name:      joid-os-nosdn-nofeature-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-nosdn-nofeature-noha-baremetal-daily-fraser/
Notes:

Name:      joid-k8-nosdn-lb-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-k8-nosdn-lb-noha-baremetal-daily-fraser/
Notes:

Name:      joid-k8-ovn-lb-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-k8-ovn-lb-noha-baremetal-daily-fraser/
Notes:

Name:      joid-os-ocl-nofeature-ha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-ocl-nofeature-ha-baremetal-daily-fraser/
Notes:

Name:      joid-os-ocl-nofeature-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-os-ocl-nofeature-noha-baremetal-daily-fraser/
Notes:

Name:      joid-k8-canal-lb-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-k8-canal-lb-noha-baremetal-daily-fraser/
Notes:

Name:      joid-k8-nosdn-lb_ceph-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-k8-nosdn-lb_ceph-noha-baremetal-daily-fraser/
Notes:

References
==========
For more information on the OPNFV Fraser release, please visit
- `OPNFV Fraser release <http://www.opnfv.org/fraser>`_

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
- `OPNFV Release Notes <http://docs.opnfv.org/en/stable-fraser/submodules/joid/docs/release/release-notes/release-notes.html>`_
- `OPNFV JOID Install Guide <http://docs.opnfv.org/en/latest/submodules/joid/docs/release/installation/index.html>`_

OpenStack
---------
- `OpenStack Pike Release artifacts <http://www.openstack.org/software/pike>`_
- `OpenStack documentation <http://docs.openstack.org>`_

OpenDaylight
------------
- `OpenDaylight artifacts <http://www.opendaylight.org/software/downloads>`_

Opencontrail
------------
- `http://www.opencontrail.org/opencontrail-quick-start-guide/`_

Kubernetes
------------
- `https://kubernetes.io/`_
