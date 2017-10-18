.. highlight:: bash


Appendices
==========


Appendix A: Single Node Deployment
----------------------------------
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
--------------------------------------
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
-------------------------------
Juju and MAAS together allow you to assign different roles to servers, so that hardware and software can be configured according to their roles. We have briefly mentioned and used this feature in our example. Please visit Juju Machine Constraints https://jujucharms.com/docs/stable/charms-constraints and MAAS tags https://maas.ubuntu.com/docs/tags.html for more information.


Appendix D: Offline Deployment
------------------------------
When you have limited access policy in your environment, for example, when only the Jump Host has Internet access, but not the rest of the servers, we provide tools in JOID to support the offline installation.

The following package set is provided to those wishing to experiment with a ‘disconnected
from the internet’ setup when deploying JOID utilizing MAAS. These instructions provide
basic guidance as to how to accomplish the task, but it should be noted that due to the
current reliance of MAAS and DNS, that behavior and success of deployment may vary
depending on infrastructure setup. An official guided setup is in the roadmap for the next release:

1.  Get the packages from here: https://launchpad.net/~thomnico/+archive/ubuntu/ubuntu-cloud-mirrors

    .. note::
        The mirror is quite large 700GB in size, and does not mirror SDN repo/ppa.

2. Additionally to make juju use a private repository of charms instead of using an external location are provided via the following link and configuring environments.yaml to use cloudimg-base-url: https://github.com/juju/docs/issues/757
