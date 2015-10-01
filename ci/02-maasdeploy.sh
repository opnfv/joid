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
sudo apt-get update -y
sudo apt-get install maas-deployer -y

cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
maas-deployer -c deployment.yaml -d --force
echo "... Deployment of maas finish ...."

maas_ip=`grep " ip_address" deployment.yaml | cut -d ":"  -f 2`

#echo "... Deployment of opnfv release Started ...."
python deploy.py $maas_ip
#echo "... Deployment of opnfv release finished ...."

