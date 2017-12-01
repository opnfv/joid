#!/bin/bash -ex

distro=$1
mkdir -p $distro

function build {
    sudo apt-get install charm-tools -y
    (cd $distro/charm-$1; charm build -s $distro  -obuild src)
    mv $distro/charm-$1/build/$distro/$1 $distro
}

# openstack
charm pull cs:ntp $distro/ntp
git clone -b stable/17.11 https://github.com/openstack/charm-ceph-mon.git $distro/ceph-mon
git clone -b stable/17.11 https://github.com/openstack/charm-ceph-osd.git $distro/ceph-osd

