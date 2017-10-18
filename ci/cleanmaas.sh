#!/bin/bash

set -ex

echo "removing existing maas ..."
sudo apt-get purge maas maas-cli maas-common maas-dhcp maas-dns maas-proxy maas-rack-controller maas-region-api maas-region-controller  -y
sudo rm -rf /var/lib/maas
