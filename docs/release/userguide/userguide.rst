
Introduction
============
This document will explain how to install OPNFV Fraser with JOID including installing JOID, configuring JOID for your environment, and deploying OPNFV with different SDN solutions in HA, or non-HA mode. Prerequisites include

- An Ubuntu 16.04 LTS Server Jumphost
- Minimum 2 Networks per Pharos requirement

  - One for the administrative network with gateway to access the Internet
  - One for the OpenStack public network to access OpenStack instances via floating IPs
  - JOID supports multiple isolated networks for data as well as storage based on your network requirement for OpenStack.

- Minimum 6 Physical servers for bare metal environment

  - Jump Host x 1, minimum H/W configuration:

    - CPU cores: 16
    - Memory: 32GB
    - Hard Disk: 1 (250GB)
    - NIC: eth0 (Admin, Management), eth1 (external network)

  - Control and Compute Nodes x 5, minimum H/W configuration:

    - CPU cores: 16
    - Memory: 32GB
    - Hard Disk: 2 (500GB) prefer SSD
    - NIC: eth0 (Admin, Management), eth1 (external network)

**NOTE**: Above configuration is minimum. For better performance and usage of the OpenStack, please consider higher specs for all nodes.

Make sure all servers are connected to top of rack switch and configured accordingly. No DHCP server should be up and configured. Configure gateways only on eth0 and eth1 networks to access the network outside your lab.

Orientation
===========
JOID in brief
^^^^^^^^^^^^^
JOID as Juju OPNFV Infrastructure Deployer allows you to deploy different combinations of
OpenStack release and SDN solution in HA or non-HA mode. For OpenStack, JOID supports
Juno and Liberty. For SDN, it supports Openvswitch, OpenContrail, OpenDayLight, and ONOS. In addition to HA or non-HA mode, it also supports deploying from the latest development tree.

JOID heavily utilizes the technology developed in Juju and MAAS. Juju is a
state-of-the-art, open source, universal model for service oriented architecture and
service oriented deployments. Juju allows you to deploy, configure, manage, maintain,
and scale cloud services quickly and efficiently on public clouds, as well as on physical
servers, OpenStack, and containers. You can use Juju from the command line or through its
powerful GUI. MAAS (Metal-As-A-Service) brings the dynamism of cloud computing to the
world of physical provisioning and Ubuntu. Connect, commission and deploy physical servers
in record time, re-allocate nodes between services dynamically, and keep them up to date;
and in due course, retire them from use. In conjunction with the Juju service
orchestration software, MAAS will enable you to get the most out of your physical hardware
and dynamically deploy complex services with ease and confidence.

For more info on Juju and MAAS, please visit https://jujucharms.com/ and http://maas.ubuntu.com.

Typical JOID Setup
^^^^^^^^^^^^^^^^^^
The MAAS server is installed and configured on Jumphost with Ubuntu 16.04 LTS with
access to the Internet. Another VM is created to be managed by MAAS as a bootstrap node
for Juju. The rest of the resources, bare metal or virtual, will be registered and
provisioned in MAAS. And finally the MAAS environment details are passed to Juju for use.

Installation
============
We will use 03-maasdeploy.sh to automate the deployment of MAAS clusters for use as a Juju provider. MAAS-deployer uses a set of configuration files and simple commands to build a MAAS cluster using virtual machines for the region controller and bootstrap hosts and automatically commission nodes as required so that the only remaining step is to deploy services with Juju. For more information about the maas-deployer, please see https://launchpad.net/maas-deployer.

Configuring the Jump Host
^^^^^^^^^^^^^^^^^^^^^^^^^
Let's get started on the Jump Host node.

The MAAS server is going to be installed and configured on a Jumphost machine. We need to create bridges on the Jump Host prior to setting up the MAAS.

**NOTE**: For all the commands in this document, please do not use a ‘root’ user account to run. Please create a non root user account. We recommend using the ‘ubuntu’ user.

Install the bridge-utils package on the Jump Host and configure a minimum of two bridges, one for the Admin network, the other for the Public network:

::

  $ sudo apt-get install bridge-utils

  $ cat /etc/network/interfaces
  # This file describes the network interfaces available on your system
  # and how to activate them. For more information, see interfaces(5).

  # The loopback network interface
  auto lo
  iface lo inet loopback

  iface p1p1 inet manual

  auto brAdm
  iface brAdm inet static
      address 172.16.50.51
      netmask 255.255.255.0
      bridge_ports p1p1

  iface p1p2 inet manual

  auto brPublic
  iface brPublic inet static
      address 10.10.15.1
      netmask 255.255.240.0
      gateway 10.10.10.1
      dns-nameservers 8.8.8.8
      bridge_ports p1p2

**NOTE**: If you choose to use separate networks for management, data, and storage, then you need to create a bridge for each interface. In case of VLAN tags, make the appropriate network on jump-host depend upon VLAN ID on the interface.

**NOTE**: The Ethernet device names can vary from one installation to another. Please change the Ethernet device names according to your environment.

MAAS has been integrated in the JOID project. To get the JOID code, please run

::

  $ sudo apt-get install git
  $ git clone https://gerrit.opnfv.org/gerrit/p/joid.git

Setting Up Your Environment for JOID
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
To set up your own environment, create a directory in joid/ci/maas/<company name>/<pod number>/ and copy an existing JOID environment over. For example:

::

  $ cd joid/ci
  $ mkdir -p ../labconfig/myown/pod
  $ cp ../labconfig/cengn/pod2/labconfig.yaml ../labconfig/myown/pod/

Now let's configure labconfig.yaml file. Please modify the sections in the labconfig as per your lab configuration.

::

lab:
  ## Change the name of the lab you want maas name will get firmat as per location and rack name ##
  location: myown
  racks:
  - rack: pod

  ## based on your lab hardware please fill it accoridngly. ##
    # Define one network and control and two control, compute and storage
    # and rest for compute and storage for backward compaibility. again
    # server with more disks should be used for compute and storage only.
    nodes:
    # DCOMP4-B, 24cores, 64G, 2disk, 4TBdisk
    - name: rack-2-m1
      architecture: x86_64
      roles: [network,control]
      nics:
      - ifname: eth0
        spaces: [admin]
        mac: ["0c:c4:7a:3a:c5:b6"]
      - ifname: eth1
        spaces: [floating]
        mac: ["0c:c4:7a:3a:c5:b7"]
      power:
        type: ipmi
        address: <bmc ip>
        user: <bmc username>
        pass: <bmc password>

  ## repeate the above section for number of hardware nodes you have it.

  ## define the floating IP range along with gateway IP to be used during the instance floating ips ##
    floating-ip-range: 172.16.120.20,172.16.120.62,172.16.120.254,172.16.120.0/24
    # Mutiple MACs seperated by space where MACs are from ext-ports across all network nodes.

  ## interface name to be used for floating ips ##
    # eth1 of m4 since tags for networking are not yet implemented.
    ext-port: "eth1"
    dns: 8.8.8.8
    osdomainname:

opnfv:
  release: d
  distro: xenial
  type: noha
  openstack: pike
  sdncontroller:
  - type: nosdn
  storage:
  - type: ceph
 ## define the maximum disk possible in your environment ##
    disk: /dev/sdb
  feature: odl_l2
 ##  Ensure the following configuration matches the bridge configuration on your jumphost
  spaces:
  - type: admin
    bridge: brAdm
    cidr: 10.120.0.0/24
    gateway: 10.120.0.254
    vlan:
  - type: floating
    bridge: brPublic
    cidr: 172.16.120.0/24
    gateway: 172.16.120.254

::


Next we will use the 03-maasdeploy.sh in joid/ci to kick off maas deployment.

Starting MAAS depoyment
^^^^^^^^^^^^^^^^^^^^^^^
Now run the 03-maasdeploy.sh script with the environment you just created

::

  ~/joid/ci$ ./03-maasdeploy.sh custom ../labconfig/mylab/pod/labconfig.yaml

This will take approximately 30 minutes to couple of hours depending on your environment. This script will do the following:
1. Create 1 VM (KVM).
2. Install MAAS on the Jumphost.
3. Configure MAAS to enlist and commission a VM for Juju bootstrap node.
4. Configure MAAS to enlist and commission bare metal servers.
5. Download and load 16.04 images to be used by MAAS.

When it's done, you should be able to view the MAAS webpage (in our example http://172.16.50.2/MAAS) and see 1 bootstrap node and bare metal servers in the 'Ready' state on the nodes page.

Troubleshooting MAAS deployment
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
During the installation process, please carefully review the error messages.

Join IRC channel #opnfv-joid on freenode to ask question. After the issues are resolved, re-running 03-maasdeploy.sh will clean up the VMs created previously. There is no need to manually undo what’s been done.

Deploying OPNFV
^^^^^^^^^^^^^^^
JOID allows you to deploy different combinations of OpenStack release and SDN solution in
HA or non-HA mode. For OpenStack, it supports Juno and Liberty. For SDN, it supports Open
vSwitch, OpenContrail, OpenDaylight and ONOS (Open Network Operating System). In addition
to HA or non-HA mode, it also supports deploying the latest from the development tree (tip).

The deploy.sh script in the joid/ci directoy will do all the work for you. For example, the following deploys OpenStack Pike with OpenvSwitch in a HA mode.

::

  ~/joid/ci$  ./deploy.sh -o pike -s nosdn -t ha -l custom -f none -m openstack

The deploy.sh script in the joid/ci directoy will do all the work for you. For example, the following deploys Kubernetes with Load balancer on the pod.

::

  ~/joid/ci$  ./deploy.sh -m openstack -f lb

Take a look at the deploy.sh script. You will find we support the following for each option::

  [-s]
    nosdn: Open vSwitch.
    odl: OpenDayLight Lithium version.
    opencontrail: OpenContrail.
    onos: ONOS framework as SDN.
  [-t]
    noha: NO HA mode of OpenStack.
    ha: HA mode of OpenStack.
    tip: The tip of the development.
  [-o]
    ocata: OpenStack Ocata version.
    pike: OpenStack Pike version.
  [-l]
    default: For virtual deployment where installation will be done on KVM created using ./03-maasdeploy.sh
    custom: Install on bare metal OPNFV defined by labconfig.yaml
  [-f]
    none: no special feature will be enabled.
    ipv6: IPv6 will be enabled for tenant in OpenStack.
    dpdk: dpdk will be enabled.
    lxd: virt-type will be lxd.
    dvr: DVR will be enabled.
    lb: Load balancing in case of Kubernetes will be enabled.
  [-d]
    xenial: distro to be used is Xenial 16.04
  [-a]
    amd64: Only x86 architecture will be used. Future version will support arm64 as well.
  [-m]
    openstack: Openstack model will be deployed.
    kubernetes: Kubernetes model will be deployed.

The script will call 01-bootstrap.sh to bootstrap the Juju VM node, then it will call 02-deploybundle.sh with the corrosponding parameter values.

::

  ./02-deploybundle.sh $opnfvtype $openstack $opnfvlab $opnfvsdn $opnfvfeature $opnfvdistro


Python script GenBundle.py would be used to create bundle.yaml based on the template
defined in the config_tpl/juju2/ directory.

By default debug is enabled in the deploy.sh script and error messages will be printed on the SSH terminal where you are running the scripts. It could take an hour to a couple of hours (maximum) to complete.

You can check the status of the deployment by running this command in another terminal::

  $ watch juju status --format tabular

This will refresh the juju status output in tabular format every 2 seconds.

Next we will show you what Juju is deploying and to where, and how you can modify based on your own needs.

OPNFV Juju Charm Bundles
^^^^^^^^^^^^^^^^^^^^^^^^
The magic behind Juju is a collection of software components called charms. They contain
all the instructions necessary for deploying and configuring cloud-based services. The
charms publicly available in the online Charm Store represent the distilled DevOps
knowledge of experts.

A bundle is a set of services with a specific configuration and their corresponding
relations that can be deployed together in a single step. Instead of deploying a single
service, they can be used to deploy an entire workload, with working relations and
configuration. The use of bundles allows for easy repeatability and for sharing of
complex, multi-service deployments.

For OPNFV, we have created the charm bundles for each SDN deployment. They are stored in
each directory in ~/joid/ci.

We use Juju to deploy a set of charms via a yaml configuration file. You can find the complete format guide for the Juju configuration file here: http://pythonhosted.org/juju-deployer/config.html

In the ‘services’ subsection, here we deploy the ‘Ubuntu Xenial charm from the charm
store,’ You can deploy the same charm and name it differently such as the second
service ‘nodes-compute.’ The third service we deploy is named ‘ntp’ and is deployed from
the NTP Trusty charm from the Charm Store. The NTP charm is a subordinate charm, which is
designed for and deployed to the running space of another service unit.

The tag here is related to what we define in the deployment.yaml file for the
MAAS. When ‘constraints’ is set, Juju will ask its provider, in this case MAAS,
to provide a resource with the tags. In this case, Juju is asking one resource tagged with
control and one resource tagged with compute from MAAS. Once the resource information is
passed to Juju, Juju will start the installation of the specified version of Ubuntu.

In the next subsection, we define the relations between the services. The beauty of Juju
and charms is you can define the relation of two services and all the service units
deployed will set up the relations accordingly. This makes scaling out a very easy task.
Here we add the relation between NTP and the two bare metal services.

Once the relations are established, Juju considers the deployment complete and moves to the next.

::

  juju  deploy bundles.yaml

It will start the deployment , which will retry the section,

::

      nova-cloud-controller:
        branch: lp:~openstack-charmers/charms/trusty/nova-cloud-controller/next
        num_units: 1
        options:
          network-manager: Neutron
        to:
          - "lxc:nodes-api=0"

We define a service name ‘nova-cloud-controller,’ which is deployed from the next branch
of the nova-cloud-controller Trusty charm hosted on the Launchpad openstack-charmers team.
The number of units to be deployed is 1. We set the network-manager option to ‘Neutron.’
This 1-service unit will be deployed to a LXC container at service ‘nodes-api’ unit 0.

To find out what other options there are for this particular charm, you can go to the code location at http://bazaar.launchpad.net/~openstack-charmers/charms/trusty/nova-cloud-controller/next/files and the options are defined in the config.yaml file.

Once the service unit is deployed, you can see the current configuration by running juju get::

  $ juju config nova-cloud-controller

You can change the value with juju config, for example::

  $ juju config nova-cloud-controller network-manager=’FlatManager’

Charms encapsulate the operation best practices. The number of options you need to configure should be at the minimum. The Juju Charm Store is a great resource to explore what a charm can offer you. Following the nova-cloud-controller charm example, here is the main page of the recommended charm on the Charm Store: https://jujucharms.com/nova-cloud-controller/trusty/66

If you have any questions regarding Juju, please join the IRC channel #opnfv-joid on freenode for JOID related questions or #juju for general questions.

Testing Your Deployment
^^^^^^^^^^^^^^^^^^^^^^^
Once juju-deployer is complete, use juju status --format tabular to verify that all deployed units are in the ready state.

Find the Openstack-dashboard IP address from the juju status output, and see if you can login via a web browser. The username and password is admin/openstack.

Optionally, see if you can log in to the Juju GUI. The Juju GUI is on the Juju bootstrap node, which is the second VM you define in the 03-maasdeploy.sh file. The username and password is admin/admin.

If you deploy OpenDaylight, OpenContrail or ONOS, find the IP address of the web UI and login. Please refer to each SDN bundle.yaml for the login username/password.

Troubleshooting
^^^^^^^^^^^^^^^
Logs are indispensable when it comes time to troubleshoot. If you want to see all the
service unit deployment logs, you can run juju debug-log in another terminal. The
debug-log command shows the consolidated logs of all Juju agents (machine and unit logs)
running in the environment.

To view a single service unit deployment log, use juju ssh to access to the deployed unit. For example to login into nova-compute unit and look for /var/log/juju/unit-nova-compute-0.log for more info.

::

  $ juju ssh nova-compute/0

Example::

  ubuntu@R4N4B1:~$ juju ssh nova-compute/0
  Warning: Permanently added '172.16.50.60' (ECDSA) to the list of known hosts.
  Warning: Permanently added '3-r4n3b1-compute.maas' (ECDSA) to the list of known hosts.
  Welcome to Ubuntu 16.04.1 LTS (GNU/Linux 3.13.0-77-generic x86_64)

  * Documentation:  https://help.ubuntu.com/
  <skipped>
  Last login: Tue Feb  2 21:23:56 2016 from bootstrap.maas
  ubuntu@3-R4N3B1-compute:~$ sudo -i
  root@3-R4N3B1-compute:~# cd /var/log/juju/
  root@3-R4N3B1-compute:/var/log/juju# ls
  machine-2.log  unit-ceilometer-agent-0.log  unit-ceph-osd-0.log  unit-neutron-contrail-0.log  unit-nodes-compute-0.log  unit-nova-compute-0.log  unit-ntp-0.log
  root@3-R4N3B1-compute:/var/log/juju#

**NOTE**: By default Juju will add the Ubuntu user keys for authentication into the deployed server and only ssh access will be available.

Once you resolve the error, go back to the jump host to rerun the charm hook with::

  $ juju resolved --retry <unit>

If you would like to start over, run juju destroy-environment <environment name> to release the resources, then you can run deploy.sh again.


The following are the common issues we have collected from the community:

- The right variables are not passed as part of the deployment procedure.

::

       ./deploy.sh -o pike -s nosdn -t ha -l custom -f none

- If you have setup maas not with 03-maasdeploy.sh then the ./clean.sh command could hang,
  the juju status command may hang because the correct MAAS API keys are not mentioned in
  cloud listing for MAAS.
  Solution: Please make sure you have an MAAS cloud listed using juju clouds.
  and the correct MAAS API key has been added.
- Deployment times out:
      use the command juju status --format=tabular and make sure all service containers receive an IP address and they are executing code. Ensure there is no service in the error state.
- In case the cleanup process hangs,run the juju destroy-model command manually.

**Direct console access** via the OpenStack GUI can be quite helpful if you need to login to a VM but cannot get to it over the network.
It can be enabled by setting the ``console-access-protocol`` in the ``nova-cloud-controller`` to ``vnc``.  One option is to directly edit the juju-deployer bundle and set it there prior to deploying OpenStack.

::

      nova-cloud-controller:
      options:
        console-access-protocol: vnc

To access the console, just click on the instance in the OpenStack GUI and select the Console tab.

Post Installation Configuration
===============================
Configuring OpenStack
^^^^^^^^^^^^^^^^^^^^^
At the end of the deployment, the admin-openrc with OpenStack login credentials will be created for you. You can source the file and start configuring OpenStack via CLI.

::

  ~/joid_config$ cat admin-openrc
  export OS_USERNAME=admin
  export OS_PASSWORD=openstack
  export OS_TENANT_NAME=admin
  export OS_AUTH_URL=http://172.16.50.114:5000/v2.0
  export OS_REGION_NAME=RegionOne

We have prepared some scripts to help your configure the OpenStack cloud that you just deployed. In each SDN directory, for example joid/ci/opencontrail, there is a ‘scripts’ folder where you can find the scripts. These scripts are created to help you configure a basic OpenStack Cloud to verify the cloud. For more information on OpenStack Cloud configuration, please refer to the OpenStack Cloud Administrator Guide: http://docs.openstack.org/user-guide-admin/. Similarly, for complete SDN configuration, please refer to the respective SDN administrator guide.

Each SDN solution requires slightly different setup. Please refer to the README in each
SDN folder. Most likely you will need to modify the openstack.sh and cloud-setup.sh
scripts for the floating IP range, private IP network, and SSH keys. Please go through
openstack.sh, glance.sh and cloud-setup.sh and make changes as you see fit.

Let’s take a look at those for the Open vSwitch and briefly go through each script so you know what you need to change for your own environment.

::

  ~/joid/juju$ ls
  configure-juju-on-openstack  get-cloud-images  joid-configure-openstack

openstack.sh
~~~~~~~~~~~~
Let’s first look at ‘openstack.sh’. First there are 3 functions defined, configOpenrc(), unitAddress(), and unitMachine().

::

  configOpenrc() {
    cat <<-EOF
        export SERVICE_ENDPOINT=$4
        unset SERVICE_TOKEN
        unset SERVICE_ENDPOINT
        export OS_USERNAME=$1
        export OS_PASSWORD=$2
        export OS_TENANT_NAME=$3
        export OS_AUTH_URL=$4
        export OS_REGION_NAME=$5
  EOF
  }

  unitAddress() {
    if [[ "$jujuver" < "2" ]]; then
        juju status --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"$1\"][\"units\"][\"$1/$2\"][\"public-address\"]" 2> /dev/null
    else
        juju status --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"applications\"][\"$1\"][\"units\"][\"$1/$2\"][\"public-address\"]" 2> /dev/null
    fi
  }

  unitMachine() {
    if [[ "$jujuver" < "2" ]]; then
        juju status --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"services\"][\"$1\"][\"units\"][\"$1/$2\"][\"machine\"]" 2> /dev/null
    else
        juju status --format yaml | python -c "import yaml; import sys; print yaml.load(sys.stdin)[\"applications\"][\"$1\"][\"units\"][\"$1/$2\"][\"machine\"]" 2> /dev/null
    fi
  }

The function configOpenrc() creates the OpenStack login credentials, the function unitAddress() finds the IP address of the unit, and the function unitMachine() finds the machine info of the unit.

::

 create_openrc() {
    keystoneIp=$(keystoneIp)
    if [[ "$jujuver" < "2" ]]; then
        adminPasswd=$(juju get keystone | grep admin-password -A 7 | grep value | awk '{print $2}' 2> /dev/null)
    else
        adminPasswd=$(juju config keystone | grep admin-password -A 7 | grep value | awk '{print $2}' 2> /dev/null)
    fi

    configOpenrc admin $adminPasswd admin http://$keystoneIp:5000/v2.0 RegionOne > ~/joid_config/admin-openrc
    chmod 0600 ~/joid_config/admin-openrc
 }

This finds the IP address of the keystone unit 0, feeds in the OpenStack admin
credentials to a new file name ‘admin-openrc’ in the ‘~/joid_config/’ folder
and change the permission of the file. It’s important to change the credentials here if
you use a different password in the deployment Juju charm bundle.yaml.

::

    neutron net-show ext-net > /dev/null 2>&1 || neutron net-create ext-net \
                                                   --router:external=True \
                                                   --provider:network_type flat \
                                                   --provider:physical_network physnet1

::
  neutron subnet-show ext-subnet > /dev/null 2>&1 || neutron subnet-create ext-net \
   --name ext-subnet --allocation-pool start=$EXTNET_FIP,end=$EXTNET_LIP \
   --disable-dhcp --gateway $EXTNET_GW $EXTNET_NET

This section will create the ext-net and ext-subnet for defining the for floating ips.

::

 openstack congress datasource create nova "nova" \
  --config username=$OS_USERNAME \
  --config tenant_name=$OS_TENANT_NAME \
  --config password=$OS_PASSWORD \
  --config auth_url=http://$keystoneIp:5000/v2.0

This section will create the congress datasource for various services.
Each service datasource will have entry in the file.

get-cloud-images
~~~~~~~~~~~~~~~~

::

 folder=/srv/data/
 sudo mkdir $folder || true

 if grep -q 'virt-type: lxd' bundles.yaml; then
    URLS=" \
    http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-lxc.tar.gz \
    http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-root.tar.gz "

 else
    URLS=" \
    http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-amd64-disk1.img \
    http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img \
    http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img \
    http://mirror.catn.com/pub/catn/images/qcow2/centos6.4-x86_64-gold-master.img \
    http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2 \
    http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img "
 fi

 for URL in $URLS
 do
 FILENAME=${URL##*/}
 if [ -f $folder/$FILENAME ];
 then
    echo "$FILENAME already downloaded."
 else
    wget  -O  $folder/$FILENAME $URL
 fi
 done

This section of the file will download the images to jumphost if not found to be used with
openstack VIM.

**NOTE**: The image downloading and uploading might take too long and time out. In this case, use juju ssh glance/0 to log in to the glance unit 0 and run the script again, or manually run the glance commands.

joid-configure-openstack
~~~~~~~~~~~~~~~~~~~~~~~~

::

 source ~/joid_config/admin-openrc

First, source the the admin-openrc file.

::
 #Upload images to glance
    glance image-create --name="Xenial LXC x86_64" --visibility=public --container-format=bare --disk-format=root-tar --property architecture="x86_64"  < /srv/data/xenial-server-cloudimg-amd64-root.tar.gz
    glance image-create --name="Cirros LXC 0.3" --visibility=public --container-format=bare --disk-format=root-tar --property architecture="x86_64"  < /srv/data/cirros-0.3.4-x86_64-lxc.tar.gz
    glance image-create --name="Trusty x86_64" --visibility=public --container-format=ovf --disk-format=qcow2 <  /srv/data/trusty-server-cloudimg-amd64-disk1.img
    glance image-create --name="Xenial x86_64" --visibility=public --container-format=ovf --disk-format=qcow2 <  /srv/data/xenial-server-cloudimg-amd64-disk1.img
    glance image-create --name="CentOS 6.4" --visibility=public --container-format=bare --disk-format=qcow2 < /srv/data/centos6.4-x86_64-gold-master.img
    glance image-create --name="Cirros 0.3" --visibility=public --container-format=bare --disk-format=qcow2 < /srv/data/cirros-0.3.4-x86_64-disk.img

upload the images into glane to be used for creating the VM.

::

  # adjust tiny image
  nova flavor-delete m1.tiny
  nova flavor-create m1.tiny 1 512 8 1

Adjust the tiny image profile as the default tiny instance is too small for Ubuntu.

::

  # configure security groups
  neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
  neutron security-group-rule-create --direction ingress --ethertype IPv4 --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default

Open up the ICMP and SSH access in the default security group.

::

  # import key pair
  keystone tenant-create --name demo --description "Demo Tenant"
  keystone user-create --name demo --tenant demo --pass demo --email demo@demo.demo

  nova keypair-add --pub-key id_rsa.pub ubuntu-keypair

Create a project called ‘demo’ and create a user called ‘demo’ in this project. Import the key pair.

::

  # configure external network
  neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat --shared
  neutron subnet-create ext-net --name ext-subnet --allocation-pool start=10.5.8.5,end=10.5.8.254 --disable-dhcp --gateway 10.5.8.1 10.5.8.0/24

This section configures an external network ‘ext-net’ with a subnet called ‘ext-subnet’.
In this subnet, the IP pool starts at 10.5.8.5 and ends at 10.5.8.254. DHCP is disabled.
The gateway is at 10.5.8.1, and the subnet mask is 10.5.8.0/24. These are the public IPs
that will be requested and associated to the instance. Please change the network configuration according to your environment.

::

  # create vm network
  neutron net-create demo-net
  neutron subnet-create --name demo-subnet --gateway 10.20.5.1 demo-net 10.20.5.0/24

This section creates a private network for the instances. Please change accordingly.

::

  neutron router-create demo-router
  neutron router-interface-add demo-router demo-subnet
  neutron router-gateway-set demo-router ext-net

This section creates a router and connects this router to the two networks we just created.

::

  # create pool of floating ips
  i=0
  while [ $i -ne 10 ]; do
    neutron floatingip-create ext-net
    i=$((i + 1))
  done

Finally, the script will request 10 floating IPs.

configure-juju-on-openstack
~~~~~~~~~~~~~~~~~~~~~~~~~~~

This script can be used to do juju bootstrap on openstack so that Juju can be used as model tool to deploy the services and VNF on top of openstack using the JOID.


Appendix A: Single Node Deployment
==================================
By default, running the script ./03-maasdeploy.sh will automatically create the KVM VMs on a single machine and configure everything for you.

::

        if [ ! -e ./labconfig.yaml ]; then
            virtinstall=1
            labname="default"
            cp ../labconfig/default/labconfig.yaml ./
            cp ../labconfig/default/deployconfig.yaml ./

Please change joid/ci/labconfig/default/labconfig.yaml accordingly. The MAAS deployment script will do the following:
1. Create bootstrap VM.
2. Install MAAS on the jumphost.
3. Configure MAAS to enlist and commission VM for Juju bootstrap node.

Later, the 03-massdeploy.sh script will create three additional VMs and register them into the MAAS Server:

::

  if [ "$virtinstall" -eq 1 ]; then
            sudo virt-install --connect qemu:///system --name $NODE_NAME --ram 8192 --cpu host --vcpus 4 \
                     --disk size=120,format=qcow2,bus=virtio,io=native,pool=default \
                     $netw $netw --boot network,hd,menu=off --noautoconsole --vnc --print-xml | tee $NODE_NAME

            nodemac=`grep  "mac address" $NODE_NAME | head -1 | cut -d '"' -f 2`
            sudo virsh -c qemu:///system define --file $NODE_NAME
            rm -f $NODE_NAME
            maas $PROFILE machines create autodetect_nodegroup='yes' name=$NODE_NAME \
                tags='control compute' hostname=$NODE_NAME power_type='virsh' mac_addresses=$nodemac \
                power_parameters_power_address='qemu+ssh://'$USER'@'$MAAS_IP'/system' \
                architecture='amd64/generic' power_parameters_power_id=$NODE_NAME
            nodeid=$(maas $PROFILE machines read | jq -r '.[] | select(.hostname == '\"$NODE_NAME\"').system_id')
            maas $PROFILE tag update-nodes control add=$nodeid || true
            maas $PROFILE tag update-nodes compute add=$nodeid || true

  fi

Appendix B: Automatic Device Discovery
======================================
If your bare metal servers support IPMI, they can be discovered and enlisted automatically
by the MAAS server. You need to configure bare metal servers to PXE boot on the network
interface where they can reach the MAAS server. With nodes set to boot from a PXE image,
they will start, look for a DHCP server, receive the PXE boot details, boot the image,
contact the MAAS server and shut down.

During this process, the MAAS server will be passed information about the node, including
the architecture, MAC address and other details which will be stored in the database of
nodes. You can accept and commission the nodes via the web interface. When the nodes have
been accepted the selected series of Ubuntu will be installed.


Appendix C: Machine Constraints
===============================
Juju and MAAS together allow you to assign different roles to servers, so that hardware and software can be configured according to their roles. We have briefly mentioned and used this feature in our example. Please visit Juju Machine Constraints https://jujucharms.com/docs/stable/charms-constraints and MAAS tags https://maas.ubuntu.com/docs/tags.html for more information.

Appendix D: Offline Deployment
==============================
When you have limited access policy in your environment, for example, when only the Jump Host has Internet access, but not the rest of the servers, we provide tools in JOID to support the offline installation.

The following package set is provided to those wishing to experiment with a ‘disconnected
from the internet’ setup when deploying JOID utilizing MAAS. These instructions provide
basic guidance as to how to accomplish the task, but it should be noted that due to the
current reliance of MAAS and DNS, that behavior and success of deployment may vary
depending on infrastructure setup. An official guided setup is in the roadmap for the next release:

1. Get the packages from here: https://launchpad.net/~thomnico/+archive/ubuntu/ubuntu-cloud-mirrors

  **NOTE**: The mirror is quite large 700GB in size, and does not mirror SDN repo/ppa.

2. Additionally to make juju use a private repository of charms instead of using an external location are provided via the following link and configuring environments.yaml to use cloudimg-base-url: https://github.com/juju/docs/issues/757

