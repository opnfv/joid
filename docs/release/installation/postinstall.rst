.. highlight:: bash

Post Installation
=================

Testing Your Deployment
-----------------------
Once Juju deployment is complete, use ``juju status`` to verify that all
deployed units are in the _Ready_ state.

Find the OpenStack dashboard IP address from the ``juju status`` output, and
see if you can login via a web browser. The domain, username and password are
``admin_domain``, ``admin`` and ``openstack``.

Optionally, see if you can log in to the Juju GUI. Run ``juju gui`` to see the
login details.

If you deploy OpenDaylight, OpenContrail or ONOS, find the IP address of the
web UI and login. Please refer to each SDN bundle.yaml for the login
username/password.

.. note::
    If the deployment worked correctly, you can get easier access to the web
    dashboards with the ``setupproxy.sh`` script described in the next section.


Create proxies to the dashboards
--------------------------------
MAAS, Juju and OpenStack/Kubernetes all come with their own web-based
dashboards. However, they might be on private networks and require SSH
tunnelling to see them. To simplify access to them, you can use the following
script to configure the Apache server on Jumphost to work as a proxy to Juju
and OpenStack/Kubernetes dashboards. Furthermore, this script also creates
JOID deployment homepage with links to these dashboards, listing also their
access credentials.

Simply run the following command after JOID has been deployed.

::

    # run in joid/ci directory
    # for OpenStack model:
    ./setupproxy.sh openstack
    # for Kubernetes model:
    ./setupproxy.sh kubernetes

You can also use the ``-v`` argument for more verbose output with xtrace.

After the script has finished, it will print out the addresses and credentials
to the dashboards. You can also find the JOID deployment homepage if you
open the Jumphost's IP address in your web browser.


Configuring OpenStack
---------------------

At the end of the deployment, the ``admin-openrc`` with OpenStack login
credentials will be created for you. You can source the file and start
configuring OpenStack via CLI.

::

  . ~/joid_config/admin-openrc

The script ``openstack.sh`` under ``joid/ci`` can be used to configure the
OpenStack after deployment.

::

    ./openstack.sh <nosdn> custom xenial pike

Below commands are used to setup domain in heat.

::

    juju run-action heat/0 domain-setup

Upload cloud images and creates the sample network to test.

::

    joid/juju/get-cloud-images
    joid/juju/joid-configure-openstack


Configuring Kubernetes
----------------------

The script ``k8.sh`` under ``joid/ci`` would be used to show the Kubernetes
workload and create sample pods.

::

    ./k8.sh


Configuring OpenStack
---------------------
At the end of the deployment, the ``admin-openrc`` with OpenStack login
credentials will be created for you. You can source the file and start
configuring OpenStack via CLI.

::

  cat ~/joid_config/admin-openrc
  export OS_USERNAME=admin
  export OS_PASSWORD=openstack
  export OS_TENANT_NAME=admin
  export OS_AUTH_URL=http://172.16.50.114:5000/v2.0
  export OS_REGION_NAME=RegionOne

We have prepared some scripts to help your configure the OpenStack cloud that
you just deployed. In each SDN directory, for example joid/ci/opencontrail,
there is a ‘scripts’ folder where you can find the scripts. These scripts are
created to help you configure a basic OpenStack Cloud to verify the cloud. For
more information on OpenStack Cloud configuration, please refer to the
OpenStack Cloud Administrator Guide:
http://docs.openstack.org/user-guide-admin/.
Similarly, for complete SDN configuration, please refer to the respective SDN
administrator guide.

Each SDN solution requires slightly different setup. Please refer to the README
in each SDN folder. Most likely you will need to modify the ``openstack.sh``
and ``cloud-setup.sh`` scripts for the floating IP range, private IP network,
and SSH keys. Please go through ``openstack.sh``, ``glance.sh`` and
``cloud-setup.sh`` and make changes as you see fit.

Let’s take a look at those for the Open vSwitch and briefly go through each
script so you know what you need to change for your own environment.

::

  $ ls ~/joid/juju
  configure-juju-on-openstack  get-cloud-images  joid-configure-openstack

openstack.sh
------------
Let’s first look at ``openstack.sh``. First there are 3 functions defined,
``configOpenrc()``, ``unitAddress()``, and ``unitMachine()``.

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
           adminPasswd=$(juju get keystone | grep admin-password -A 5 | grep value | awk '{print $2}' 2> /dev/null)
       else
           adminPasswd=$(juju config keystone | grep admin-password -A 5 | grep value | awk '{print $2}' 2> /dev/null)
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
----------------

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

This section of the file will download the images to jumphost if not found to
be used with openstack VIM.

.. note::
    The image downloading and uploading might take too long and time out. In
    this case, use juju ssh glance/0 to log in to the glance unit 0 and run the
    script again, or manually run the glance commands.

joid-configure-openstack
------------------------

::

 source ~/joid_config/admin-openrc

First, source the the ``admin-openrc`` file.

::
    #Upload images to glance
    glance image-create --name="Xenial LXC x86_64" --visibility=public --container-format=bare --disk-format=root-tar --property architecture="x86_64"  < /srv/data/xenial-server-cloudimg-amd64-root.tar.gz
    glance image-create --name="Cirros LXC 0.3" --visibility=public --container-format=bare --disk-format=root-tar --property architecture="x86_64"  < /srv/data/cirros-0.3.4-x86_64-lxc.tar.gz
    glance image-create --name="Trusty x86_64" --visibility=public --container-format=ovf --disk-format=qcow2 <  /srv/data/trusty-server-cloudimg-amd64-disk1.img
    glance image-create --name="Xenial x86_64" --visibility=public --container-format=ovf --disk-format=qcow2 <  /srv/data/xenial-server-cloudimg-amd64-disk1.img
    glance image-create --name="CentOS 6.4" --visibility=public --container-format=bare --disk-format=qcow2 < /srv/data/centos6.4-x86_64-gold-master.img
    glance image-create --name="Cirros 0.3" --visibility=public --container-format=bare --disk-format=qcow2 < /srv/data/cirros-0.3.4-x86_64-disk.img

Upload the images into Glance to be used for creating the VM.

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


