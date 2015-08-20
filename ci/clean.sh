#!/bin/bash

set -ex

#juju-deployer -T -d
juju destroy-environment maas  -y
rm -rf ~/.juju/j*
rm -rf ~/.juju/environments
rm -rf ~/.juju/ssh
rm -rf ~/.juju/.deployer-store-cache

