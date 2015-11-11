#!/bin/sh -e

. ~/admin-openrc

wget -P /tmp/images http://download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
wget -P /tmp/images http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
glance image-create --name ubuntu-trusty-daily --disk-format qcow2 --container-format bare --owner admin --file /tmp/imaes/trusty-server-cloudimg-amd64-disk1.img --checksum $(grep trusty-server-cloudimg-amd64-disk1.img MD5SUMS | cut -d " " -f 1) --is-public True
glance image-create --name "cirros-0.3.3-x86_64" --file /tmp/images/cirros-0.3.3-x86_64-disk.img --disk-format qcow2 --container-format bare --is-public True -owner admin --progress
rm -rf /tmp/images
