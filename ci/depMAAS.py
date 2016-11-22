#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
This script generates a maas deployer config based on lab config file.

Parameters:
 -l, --lab      : lab config file
"""

from optparse import OptionParser
from jinja2 import Environment, FileSystemLoader
from distutils.version import LooseVersion, StrictVersion
import os
import subprocess
import yaml
from pprint import pprint as pp
import socket
import fcntl
import struct

#
# Parse parameters
#

parser = OptionParser()
parser.add_option("-l", "--lab", dest="lab", help="lab config file")
(options, args) = parser.parse_args()
labconfig_file = options.lab

#
# Set Path and configs path
#

# Capture our current directory
jujuver = subprocess.check_output(["juju", "--version"])

if LooseVersion(jujuver) >= LooseVersion('2'):
    TPL_DIR = os.path.dirname(os.path.abspath(__file__))+'/config_tpl/maas_tpl'
else:
    TPL_DIR = os.path.dirname(os.path.abspath(__file__))+'/config_tpl/maas2/maas_tpl'

HOME = os.environ['HOME']
USER = os.environ['USER']

#
# Prepare variables
#

# Prepare a storage for passwords
passwords_store = dict()

#
# Local Functions
#


def load_yaml(filepath):
    """Load YAML file"""
    with open(filepath, 'r') as stream:
        try:
            return yaml.load(stream)
        except yaml.YAMLError as exc:
            print(exc)


def get_ip_address(ifname):
    """Get local IP"""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', bytes(ifname.encode('utf-8')[:15]))
    )[20:24])


#
# Config import
#

def installMAAS():
    subprocess.call(["echo", i], shell=True)

def configMAAS():
    
    
# Create the jinja2 environment.
env = Environment(loader=FileSystemLoader(TPL_DIR),
                  trim_blocks=True)
template = env.get_template('deployment.yaml')

# Render the template
output = template.render(**config)

# Check output syntax
try:
    yaml.load(output)
except yaml.YAMLError as exc:
    print(exc)

# print output
print(output)
