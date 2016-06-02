import yaml
import pprint
import socket
import fcntl
import struct
import os
import getpass

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])

with open('labconfig.yaml', 'r') as labf:
    labcfg = yaml.load(labf)

opnfvcfg={}
opnfvlabcfg={}

def getFromDict(dataDict, mapList):
    return reduce(lambda d, k: d[k], mapList, dataDict)

#lets define the bootstrap section
opnfvcfg['demo-maas']={'juju-bootstrap':{'memory': 4096,'name': "bootstrap",\
                                         'pool': "default", 'vcpus': 4,\
                                         'disk_size': "60G", 'arch': "amd64",\
                                         'interfaces':[]},\
                       'maas':{'memory': 4096,'pool': "default", 'vcpus': 4,\
                               'disk_size': "160G", 'arch': "amd64", 'interfaces':[],\
                               'name':"",'network_config':[],'node_group_ifaces':[],\
                               'nodes':[],'password': 'ubuntu', 'user':'ubuntu',\
                               'release': 'trusty', 'apt_sources':[],'ip_address':'',\
                               'boot_source':{'keyring_filename':\
                                                "/usr/share/keyrings/ubuntu-cloudimage-keyring.gpg",\
                                             'url': \
                                             "http://maas.ubuntu.com/images/ephemeral-v2/releases/",\
                                             'selections':{'1':{'arches':'amd64','labels':'release',\
                                                                'os':'ubuntu','release':'xenial',\
                                                                'subarches':'*'
                                                               }\
                                                          }\
                                             },\
                              'settings':{'maas_name':'','upstream_dns':'',\
                                          'main_archive':"http://us.archive.ubuntu.com/ubuntu"\
                                         },\
                              'virsh':{'rsa_priv_key':'/home/ubuntu/.ssh/id_rsa',
                                       'rsa_pub_key':'/home/ubuntu/.ssh/id_rsa.pub',
                                       'uri':''
                                      }\
                              }\
                      }

opnfvlabcfg['opnfv']={'ext-port':'','floating-ip-range':'','dataNetwork':'','ceph-disk':'/srv/'}

opnfvcfg['demo-maas']['maas']['apt_sources'].append("ppa:maas/stable")
opnfvcfg['demo-maas']['maas']['apt_sources'].append("ppa:juju/stable")

# lets modify the maas general settings:

updns = getFromDict(labcfg, ["lab","racks",0,"dns"])
opnfvcfg["demo-maas"]["maas"]["settings"]["upstream_dns"]=updns

location = getFromDict(labcfg, ["lab","location"])
rack = getFromDict(labcfg, ["lab","racks",0,"rack"])
value=location+rack

opnfvcfg["demo-maas"]["maas"]["settings"]["maas_name"]=value
opnfvcfg["demo-maas"]["maas"]["name"]="opnfv-"+value

ethbrAdm=""
ethbrAdmin=""

c=0
y=0
#z=0

while c < len(labcfg["opnfv"]["spaces"]):
    brtype = getFromDict(labcfg, ["opnfv","spaces",c,"type"])
    brname = getFromDict(labcfg, ["opnfv","spaces",c,"bridge"])
    brcidr = getFromDict(labcfg, ["opnfv","spaces",c,"cidr"])
#
    if brtype == "admin":
        ethbrAdmin = getFromDict(labcfg, ["opnfv","spaces",c,"bridge"])
        brgway = getFromDict(labcfg, ["opnfv","spaces",c,"gateway"])
        tmpcidr = brcidr[:-4]
        opnfvlabcfg["opnfv"]["admNetwork"]=tmpcidr+"2"

        nodegroup={"device": "eth"+str(y), "ip": tmpcidr+"5","subnet_mask": "255.255.255.0", \
                   "broadcast_ip": tmpcidr+"255", "router_ip": brgway,\
                   "static_range":{"high":tmpcidr+"80","low":tmpcidr+"50"},\
                   "dynamic_range":{"high":tmpcidr+"250","low":tmpcidr+"81"}}

        ethbrAdm = ('auto lo\n'
                    '    iface lo inet loopback\n\n'
                    'auto eth'+str(y)+'\n'
                    '    iface eth'+str(y)+' inet static\n'
                    '    address '+tmpcidr+'5\n'
                    '    netmask 255.255.255.0\n'
                    '    gateway '+brgway+'\n'
                    '    dns-nameservers '+updns+' '+tmpcidr+'5 127.0.0.1\n')

        opnfvcfg['demo-maas']['maas']['ip_address']=tmpcidr+"5"
        opnfvcfg['demo-maas']['maas']['interfaces'].append("bridge="+brname+",model=virtio")
        opnfvcfg['demo-maas']['juju-bootstrap']['interfaces'].append("bridge="+brname+",model=virtio")
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"].append(nodegroup)
        y=y+1
    elif brtype:
        opnfvcfg["demo-maas"]["maas"]["interfaces"].append("bridge="+brname+",model=virtio")
        brgway = getFromDict(labcfg, ["opnfv","spaces",c,"gateway"])
        if brtype != "external":
            tmpcidr = brcidr[:-4]
            if brgway:
                nodegroup={"device": "eth"+str(y), "ip": tmpcidr+"5","subnet_mask": "255.255.255.0", \
                           "broadcast_ip": tmpcidr+"255", "management": 1, "router_ip": brgway,\
                           "static_range":{"high":tmpcidr+"80","low":tmpcidr+"50"},\
                           "dynamic_range":{"high":tmpcidr+"250","low":tmpcidr+"81"}}
            else:
                nodegroup={"device": "eth"+str(y), "ip": tmpcidr+"5","subnet_mask": "255.255.255.0", \
                           "broadcast_ip": tmpcidr+"255", "management": 1, \
                           "static_range":{"high":tmpcidr+"80","low":tmpcidr+"50"},\
                           "dynamic_range":{"high":tmpcidr+"250","low":tmpcidr+"81"}}
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"].append(nodegroup)
            ethbrAdm  = (ethbrAdm+'\n'
                        'auto eth'+str(y)+'\n'
                        '    iface eth'+str(y)+' inet static\n'
                        '    address '+tmpcidr+'5\n'
                        '    netmask 255.255.255.0\n')
            y=y+1
        if brtype == "public":
            opnfvcfg["demo-maas"]["juju-bootstrap"]["interfaces"].append("bridge="+brname+",model=virtio")
        if brtype == "external":
            ipaddress = getFromDict(labcfg, ["opnfv","spaces",c,"ipaddress"])
            ethbrAdm  = (ethbrAdm+'\n'
                        'auto eth'+str(y)+'\n'
                        '    iface eth'+str(y)+' inet static\n'
                        '    address '+ipaddress+'\n'
                        '    netmask 255.255.255.0\n')
            opnfvcfg["demo-maas"]["juju-bootstrap"]["interfaces"].append("bridge="+brname+",model=virtio")
        if brtype == "data":
            opnfvlabcfg["opnfv"]["dataNetwork"]=brcidr

    c=c+1

# lets modify the maas general settings:
value = get_ip_address(ethbrAdmin)
value = "qemu+ssh://"+getpass.getuser()+"@"+value+"/system"
opnfvcfg['demo-maas']['maas']['virsh']['uri']=value
opnfvcfg['demo-maas']['maas']['network_config']=ethbrAdm

if len(labcfg["lab"]["racks"][0]["nodes"]) < 1:
    print("looks like virtual deployment where nodes were not defined")
    opnfvcfg["demo-maas"]["maas"]["nodes"].remove()
    exit()

#lets insert the node details here:
c=0
#
while c < len(labcfg["lab"]["racks"][0]["nodes"]):
    valuemac=[]
    y = 0
    # setup value of name and tags accordigly
    noderoleslist = labcfg["lab"]["racks"][0]["nodes"][c]["roles"]
    noderoles = " ".join(noderoleslist)

    valuetype = getFromDict(labcfg, ["lab","racks",0,"nodes",c, "power", "type"])
    namevalue = labcfg["lab"]["racks"][0]["nodes"][c]["name"]
    valuearc = getFromDict(labcfg, ["lab","racks",0,"nodes",c, "architecture"])
    # setup value of architecture
    if valuearc == "x86_64":
        valuearc="amd64/generic"

    if valuetype == "wakeonlan":
        macvalue = getFromDict(labcfg, ["lab","racks",0,"nodes",c, "power", "mac_address"])
        power={"type": "ether_wake", "mac_address": macvalue}
    if valuetype == "ipmi":
        valueaddr = getFromDict(labcfg, ["lab","racks",0,"nodes",c, "power", "address"])
        valueuser = getFromDict(labcfg, ["lab","racks",0,"nodes",c, "power", "user"])
        valuepass = getFromDict(labcfg, ["lab","racks",0,"nodes",c, "power", "pass"])
        valuedriver = "LAN_2_0"
        power={"type": valuetype, "address": valueaddr,"user": valueuser,\
               "pass": valuepass, "driver": valuedriver}

    opnfvcfg["demo-maas"]["maas"]["nodes"].append({"name": namevalue, \
             "architecture":valuearc,"interfaces":[],"mac_addresses":[],\
             "power":power,'tags':noderoles})
    y = 0
    while y < len(labcfg["lab"]["racks"][0]["nodes"][c]["nics"]):
        valueifname = labcfg["lab"]["racks"][0]["nodes"][c]["nics"][y]["ifname"]
        valueifmac = labcfg["lab"]["racks"][0]["nodes"][c]["nics"][y]["mac"][0]
        valuemac += labcfg["lab"]["racks"][0]["nodes"][c]["nics"][y]["mac"]
        opnfvcfg["demo-maas"]["maas"]["nodes"][c]["interfaces"]\
                 .append({"name":valueifname,"mac_address":valueifmac,"mode": "auto"})

        y=y+1

    if valueifmac:
       opnfvcfg["demo-maas"]["maas"]["nodes"][c]['mac_addresses']=valuemac

    c=c+1

opnfvlabcfg["opnfv"]["floating-ip-range"]=labcfg["lab"]["racks"][0]["floating-ip-range"]
opnfvlabcfg["opnfv"]["ext-port"]=labcfg["lab"]["racks"][0]["ext-port"]
opnfvlabcfg["opnfv"]["ceph-disk"]=labcfg["opnfv"]["storage"][0]["disk"]

with open('deployment.yaml', 'wa') as opnfvf:
   yaml.dump(opnfvcfg, opnfvf, default_flow_style=False)

with open('deployconfig.yaml', 'wa') as opnfvf:
   yaml.dump(opnfvlabcfg, opnfvf, default_flow_style=False)
