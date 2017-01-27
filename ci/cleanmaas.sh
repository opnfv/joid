#!/bin/bash

set -ex

maasver=$(apt-cache policy maas | grep Installed | cut -d ':' -f 2 | sed -e 's/^.*: //')

if [[ "$maasver" > "2" ]]; then
    echo "removing existing maas ..."
    sudo apt-get purge maas maas-cli maas-common maas-dhcp maas-dns maas-proxy maas-rack-controller maas-region-api maas-region-controller  -y
    sudo rm -rf /var/lib/maas
fi
