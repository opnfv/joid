#!/bin/bash
#placeholder for deployment script.
set -ex

case "$1" in
    'intelpod5' )
        cp maas/intel/pod5/deployment.yaml ./deployment.yaml
        ;;
    'intelpod6' )
        cp maas/intel/pod6/deployment.yaml ./deployment.yaml
        ;;
    'orangepod2' )
        cp maas/orange/pod2/deployment.yaml ./deployment.yaml
        ;;
    'attvirpod1' )
        cp maas/att/virpod1/deployment.yaml ./deployment.yaml
        ;;
    * )
        cp maas/intel/pod5/deployment.yaml ./deployment.yaml
        ;;
esac

echo "... Deployment of maas Started ...."

if [ ! -e $HOME/.ssh/id_rsa ]; then
    ssh-keygen -N '' -f $HOME/.ssh/id_rsa
fi

if [ ! -e /var/lib/libvirt/images ]; then

    sudo apt-get install libvirt-bin -y
    sudo adduser ubuntu libvirtd
    sudo virsh pool-define /dev/stdin <<EOF
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool>
EOF

    sudo virsh pool-start default
    sudo virsh pool-autostart default

fi

sudo apt-add-repository ppa:maas-deployers/stable -y
sudo apt-add-repository ppa:juju/stable -y
sudo apt-add-repository ppa:maas/stable -y
sudo apt-get update -y
sudo apt-get install git maas-deployer juju juju-deployer maas-cli -y
juju init -f

cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
maas-deployer -c deployment.yaml -d --force

echo "... Deployment of maas finish ...."

maas_ip=`grep " ip_address" deployment.yaml | cut -d " "  -f 10`
apikey=`grep maas-oauth: environments.yaml | cut -d "'" -f 2`
maas login maas http://${maas_ip}/MAAS/api/1.0 ${apikey}
maas maas boot-source update 1 url="http://maas.ubuntu.com/images/ephemeral-v2/daily/"
#maas maas boot-source-selections create 1 os="ubuntu" release="precise" arches="amd64" subarches="*" labels="*"
maas maas boot-resources import
maas maas sshkeys new key="`cat $HOME/.ssh/id_rsa.pub`"
#maas maas sshkeys new key="`cat $HOME/.ssh/id_maas.pub`"

#echo "... Deployment of opnfv release Started ...."
#python deploy.py $maas_ip
#echo "... Deployment of opnfv release finished ...."

