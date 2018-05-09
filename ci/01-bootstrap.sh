#!/bin/bash

set -ex

controllername=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`
cloudname=`awk 'NR==1{print substr($1, 1, length($1)-1)}' deployconfig.yaml`
juju bootstrap $controllername $cloudname --debug --constraints tags=bootstrap --bootstrap-series=$1
