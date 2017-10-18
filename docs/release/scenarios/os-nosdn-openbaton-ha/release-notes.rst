.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>


Abstract
========

This document compiles the release notes for the Euphrates release of
OPNFV when using JOID as a deployment tool with the Open Baton NFV MANO framework
 provided by the OPNFV orchestra project.

Introduction
============

These notes provides release information for the use of joid as deployment
tool for the Euphrates release of OPNFV for orchestra
scenario.

The goal of the Euphrates release and this JOID based deployment process is
to establish a lab ready platform accelerating further development
of the OPNFV infrastructure.

Carefully follow the installation-instructions which guides a user to deploy
OPNFV using JOID which is based on MAAS and Juju.

Summary
=======

The OPNFV Orchestra project integrates the upstream open source Open Baton project within OPNFV.
Open Baton is the result of an agile design process having as major objective the development
of an extensible and customizable framework capable of orchestrating network services across
heterogeneous NFV Infrastructures.

Euphrates release with the JOID deployment enables deployment of orchestra
 on a Pharos compliant lab infrastructure.

The current definition of an OPNFV target system is based on OpenStack Ocata.

    The system is deployed with OpenStack High Availability (HA) for most OpenStack services.

    User has following choices to make to do the deployment.

    - Openstack      -- Ocata
    - Type           -- HA, nonHA, tip (stable git branch of respective openstack)
    - Feature        -- Open Baton (NFV MANO framework)

NOTE: Detailed information on how to install in your lab can be find in installation guide
command to deploy orchestra feature is:

#Orchestra deployment with no HA Openstack
./deploy.sh -o ocata -m openstack -f openbaton -s nosdn -t nonha

#Orchestra deployment with no HA Openstack
./deploy.sh -o ocata -m openstack -f openbaton -s nosdn -t ha


Using Openstack
===============

admin-openrc file have been placed under ~/joid_config/
Please source the same and use OpenStack API to do rest of the configuration.

Using Orchestra (Open Baton) after Deployment
=============================================

Considering that there are no major differences between the Open Baton installed within
OPNFV platform and the upstream one, feel free to follow the upstram documentation provided
by the Open Baton project to learn more advanced use cases: http://openbaton.github.io/documentation/

Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | JOID                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | gerrit.opnfv.org/gerrit/joid.git     |
|                                      | stable/euphrates                     |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Euphrates release                    |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | October 24 2017                      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | Euphrates release                    |
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

Name:      os-nosdn-openbaton-ha
Test Link: https://build.opnfv.org/ci/job/joid-deploy-baremetal-daily-euphrates
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

Orchestra
---------
- `Orchestra Release Notes <http://docs.opnfv.org/en/stable-euphrates/submodules/orchestra/docs/release/release-notes/index.html#orchestra-releasenotes>`_
- `Open Baton documentation <http://openbaton.github.io/documentation/>`_

