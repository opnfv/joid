#!/bin/bash
##############################################################################
# Copyright (c) 2017 Nokia and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#
# Small tool to setup IP forwarding if you need Internet connectivity on both
# bridges but only one of the interfaces actually has the outside connectivity.
# Based on a script provided by Canonical
#

# Internal bridge
internal="brAdmin"
# External bridge with Internet connectivity
external="brExt"

set -ex

if [ "$(id -u)" != "0" ]; then
    echo "Must be run with sudo or by root"
    exit 77
fi

# Enable IP forwarding and save for next boot
echo 1 > /proc/sys/net/ipv4/ip_forward
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/10-maas-ip-forward.conf
sysctl --system

# Note that this script assumes no existing iptables rules.
# If you do have any, they will be deleted.
iptables -v --flush
iptables -v --table nat --flush
iptables -v --delete-chain
iptables -v --table nat --delete-chain

# Some things use the MAAS proxy - some things don't. So turn on NAT.
echo "Setting up ip forwarding"
iptables -v -t nat -A POSTROUTING -o $external -j MASQUERADE
iptables -v -A FORWARD -i $external -o $internal -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -v -A FORWARD -i $internal -o $external -j ACCEPT

# Make the rules persistent (otherwise it's reset after next boot)
apt-get install netfilter-persistent

# sudo is needed here even when the script is called with sudo,
# otherwise the output is empty
mkdir -p /etc/iptables
sudo iptables-save > /etc/iptables/rules.v4
echo "Saved iptables rules:"
cat /etc/iptables/rules.v4

service netfilter-persistent restart
