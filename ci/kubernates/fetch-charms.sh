#!/bin/bash -ex

distro=$1
mkdir -p $distro

function build {
    sudo apt-get install charm-tools -y
    (cd $distro/charm-$1; charm build -s $distro  -obuild src)
    mv $distro/charm-$1/build/$distro/$1 $distro
}

# openstack
charm pull cs:~containers/kubernetes-master $distro/kubernetes-master
charm pull cs:~containers/kubernetes-worker $distro/kubernetes-worker
charm pull cs:~containers/flannel $distro/flannel
charm pull cs:~containers/etcd $distro/etcd
charm pull cs:~containers/easyrca $distro/easyrca
