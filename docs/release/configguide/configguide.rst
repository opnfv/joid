JOID Configuration
==================

Scenario 1: Nosdn
-----------------

*./deploy.sh -o ocata -s nosdn -t ha -l custom -f none -d xenial -m openstack*

Scenario 2: Kubernetes core
---------------------------

*./deploy.sh -l custom -f none -m kubernetes*

Scenario 3: Kubernetes Load Balancer
------------------------------------

*./deploy.sh -l custom -f lb -m kubernetes*

Scenario 4: Kubernetes with OVN
-------------------------------

*./deploy.sh -s ovn -l custom -f lb -m kubernetes*

Scenario 5: Openstack with Opencontrail
---------------------------------------

*./deploy.sh -o ocata -s ocl -t ha -l custom -f none -d xenial -m openstack*
