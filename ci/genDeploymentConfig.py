#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
This script generates a deployment config based on lab config file.

Parameters:
 -l, --lab      : lab config file
"""

from optparse import OptionParser
from jinja2 import Environment, FileSystemLoader
from distutils.version import LooseVersion, StrictVersion
import os
import yaml
import subprocess

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
    TPL_DIR = os.path.dirname(os.path.abspath(__file__))+'/config_tpl/juju2'
else:
    TPL_DIR = os.path.dirname(os.path.abspath(__file__))+'/config_tpl'

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

#
# Config import
#

# Load scenario Config
config = load_yaml(labconfig_file)

# Set a dict copy of opnfv/spaces
config['opnfv']['spaces_dict'] = dict()
for space in config['opnfv']['spaces']:
    config['opnfv']['spaces_dict'][space['type']] = space

# Set a dict copy of opnfv/storage
config['opnfv']['storage_dict'] = dict()
for storage in config['opnfv']['storage']:
    config['opnfv']['storage_dict'][storage['type']] = storage

# Add some OS environment variables
config['os'] = {'home': HOME,
                'user': USER,
                }

# Prepare interface-enable, more easy to do it here
ifnamelist = set()
for node in config['lab']['racks'][0]['nodes']:
    for nic in node['nics']:
        if 'admin' not in nic['spaces']:
            ifnamelist.add(nic['ifname'])
config['lab']['racks'][0]['ifnamelist'] = ','.join(ifnamelist)

#
# Transform template to deployconfig.yaml according to config
#

# Create the jinja2 environment.
env = Environment(loader=FileSystemLoader(TPL_DIR),
                  trim_blocks=True)
template = env.get_template('deployconfig.yaml')

# Render the template
output = template.render(**config)

# Check output syntax
try:
    yaml.load(output)
except yaml.YAMLError as exc:
    print(exc)

# print output
print(output)
