JOID Configuration
==================

Scenario 1: ODL L2
------------------

*./deploy.sh -o newton -s odl -t ha -l custom -f none -d xenial -m openstack*

Scenario 2: Nosdn
-----------------

*./deploy.sh -o newton -s nosdn -t ha -l custom -f none -d xenial -m openstack*

Scenario 3: ONOS nofeature
--------------------------

*./deploy.sh -o newton -s onos -t ha -l custom -f none -d xenial -m openstack*

Scenario 4: ONOS with SFC
------------------

*./deploy.sh -o newton -s onos -t ha -l custom -f none -d xenial -m openstack*

Scenario 5: Kubernetes core
---------------------------

*./deploy.sh -l custom -f none -m kubernetes*
