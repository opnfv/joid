#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
This script generates a bundle config for the haproxy managing public apis

Parameters:
 -l, --lab      : lab config file
"""

from jinja2 import Environment, FileSystemLoader
from keystoneauth1.identity import v2
from keystoneauth1 import session
from keystoneclient.v2_0 import client
from optparse import OptionParser

import os
import yaml

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
TPL_DIR = os.path.dirname(os.path.abspath(__file__))+'/config_tpl'

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

# Add public api ip to config
if 'public_api_ip' in config['lab']['racks'][0]:
    config['public_api_ip'] = config['lab']['racks'][0]['public_api_ip']
else:
    first_public_ip = config['lab']['racks'][0][
                        'floating-ip-range'].split(',')[0]
    # managing ipv6 and ipv4 format
    sep = ':' if ':' in first_public_ip else '.'
    api_ip = first_public_ip.split(sep)
    api_ip[-1] = str(int(api_ip[-1])-1)
    config['public_api_ip'] = sep.join(api_ip)

# get endpoint list from keystone
username = os.environ['OS_USERNAME']
password = os.environ['OS_PASSWORD']
tenant_name = os.environ['OS_TENANT_NAME']
auth_url = os.environ['OS_AUTH_URL']
auth = v2.Password(username=username,
                   password=password,
                   tenant_name=tenant_name,
                   auth_url=auth_url)
sess = session.Session(auth=auth)
keystone = client.Client(session=sess)
services = keystone.services.list()
endpoints = keystone.endpoints.list()
srv = dict()
for service in services:
    if service.name != 'cinderv2':
        srv[service.id] = {'name': service.name}
for endpoint in endpoints:
    if endpoint.service_id in srv.keys():
        internal = endpoint.internalurl.split('/')[2].split(':')
        srv[endpoint.service_id]['ip'] = ':'.join(internal[:-1])
        srv[endpoint.service_id]['port'] = internal[-1]
config['public_api_services'] = srv

#
# Transform template to deployconfig.yaml according to config
#

# Create the jinja2 environment.
env = Environment(loader=FileSystemLoader(TPL_DIR),
                  trim_blocks=True)
template = env.get_template('public-api-proxy.yaml')

# Render the template
output = template.render(**config)

# Check output syntax
try:
    yaml.load(output)
except yaml.YAMLError as exc:
    print(exc)

# print output
print(output)
