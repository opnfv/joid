#!/bin/bash
#placeholder for deployment script.
set -ex

case "$1" in
    'intelpod5' )
        cp intel/pod5/maas/deployment.yaml ./deployment.yaml
        ;;
    * )
        cp intel/pod5/maas/deployment.yaml ./deployment.yaml
        ;;
esac

echo "... Deployment of maas Started ...."
sudo apt-add-repository ppa:maas-deployers/stable -y
sudo apt-get update -y
sudo apt-get install maas-deployer -y
if [ ! -e /home/ubuntu/.ssh/id_rsa ]; then
    ssh-keygen -N '' -f /home/ubuntu/.ssh/id_rsa
fi
sudo adduser ubuntu libvirtd
cat /home/ubuntu/.ssh/id_rsa.pub > /home/ubuntu/.ssh/authorized_keys
maas-deployer -c deployment.yaml -d --force
echo "... Deployment of maas finish ...."

maas_ip=`grep " ip_address" deployment.yaml | cut -d ":"  -f 2`

#echo "... Deployment of opnfv release Started ...."
python deploy.py $maas_ip
#echo "... Deployment of opnfv release finished ...."

