.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. (c) <optionally add copywriters name>


Abstract
========

This document compiles the release notes for the Fraser release of
OPNFV when using JOID as a deployment tool for Kubernets and load balancer.

Introduction
============

These notes provides release information for the use of joid as deployment
tool for the Fraser release of OPNFV for Kubernets and load balancer
scenario.

The goal of the Fraser release and this JOID based deployment process is
to establish a lab ready platform accelerating further development
of the OPNFV infrastructure for docker based workloads.

Carefully follow the installation-instructions which guides a user to deploy
OPNFV using JOID which is based on MAAS and Juju.

Summary
=======

Kubernetes is an open-source system for automating deployment, scaling, and
management of containerized applications.

This is a Kubernetes cluster that includes logging, monitoring, and operational
knowledge. It is comprised of the following components and features:

Kubernetes (automated deployment, operations, and scaling)
  TLS used for communication between nodes for security.
  A CNI plugin (e.g., Flannel, Ovn)
  A load balancer for HA kubernetes-master (Experimental)
  Optional Ingress Controller (on worker)
  Optional Dashboard addon (on master) including Heapster for cluster monitoring

EasyRSA
 Performs the role of a certificate authority serving self signed certificates
 to the requesting units of the cluster.

Etcd (distributed key value store)
 Minimum Three node cluster for reliability.

Fraser release with the JOID deployment with Kubernetes with load balancer will establish an
OPNFV target system on a Pharos compliant lab infrastructure.

NOTE: Detailed information on how to install in your lab can be find in installation guide
command to deploy load balancer feature is:

#Kubernetes deployment with Load Balancer
./deploy.sh -m kubernetes -f lb -l custom -s nosdn

Using Kubernetes after Deployment
=================================

Once you have finished installinf the JOID with Kubernetes with load balancer you can use the
following command to test the deployment.

To deploy 5 replicas of the microbot web application inside the Kubernetes
cluster run the following command:

juju run-action kubernetes-worker/0 microbot replicas=5

This action performs the following steps:

It creates a deployment titled 'microbots' comprised of 5 replicas defined
during the run of the action. It also creates a service named 'microbots'
which binds an 'endpoint', using all 5 of the 'microbots' pods.
Finally, it will create an ingress resource, which points at a
xip.io domain to simulate a proper DNS service.

Running the packaged example

You can run a Juju action to create an example microbot web application:

$ juju run-action kubernetes-worker/0 microbot replicas=3
Action queued with id: db7cc72b-5f35-4a4d-877c-284c4b776eb8

$ juju show-action-output db7cc72b-5f35-4a4d-877c-284c4b776eb8
results:
  address: microbot.104.198.77.197.xip.io
status: completed
timing:
  completed: 2016-09-26 20:42:42 +0000 UTC
  enqueued: 2016-09-26 20:42:39 +0000 UTC
  started: 2016-09-26 20:42:41 +0000 UTC
Note: Your FQDN will be different and contain the address of the cloud
instance.
At this point, you can inspect the cluster to observe the workload coming
online.

Mor einformation on using Canonical distribution of kubernetes can be found
at https://jujucharms.com/canonical-kubernetes/

Release Data
============

+--------------------------------------+--------------------------------------+
| **Project**                          | JOID                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | gerrit.opnfv.org/gerrit/joid.git     |
|                                      | stable/fraser                     |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Fraser release                    |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | March 31 2018                        |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | Fraser release                    |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

Deliverables
------------

Software deliverables
~~~~~~~~~~~~~~~~~~~~~
`JOID based installer script files <https://gerrit.opnfv.org/gerrit/gitweb?p=joid.git>`_

Known Limitations, Issues and Workarounds
=========================================

Known issues
------------

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA:                                | No support for functest for          |
|                                      | Kubernetes scenarios  (OPNFV)        |
+--------------------------------------+--------------------------------------+
| JIRA:                                |                                      |
+--------------------------------------+--------------------------------------+


Scenario Releases
=================
Name:      joid-k8-ovn-lb-noha
Test Link: https://build.opnfv.org/ci/view/joid/job/joid-k8-ovn-lb-noha-baremetal-daily-fraser/
Notes:

References
==========

Juju
----
- `Juju Charm store <https://jujucharms.com/>`_
- `Juju documents <https://jujucharms.com/docs/stable/getting-started>`_
- `Canonical Distibuytion of Kubernetes <https://jujucharms.com/canonical-kubernetes/>`_

MAAS
----
- `Bare metal management (Metal-As-A-Service) <http://maas.io/get-started>`_
- `MAAS API documents <http://maas.ubuntu.com/docs/>`_

JOID
----
- `OPNFV JOID wiki <https://wiki.opnfv.org/joid>`_
- `OPNFV JOID Get Started <https://wiki.opnfv.org/display/joid/JOID+Get+Started>`_

Kubernetes
----------
- `Kubernetes Release artifacts <https://get.k8s.io/>`_
- `Kubernetes documentation <https://kubernetes.io/>`_

