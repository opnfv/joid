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

with open('deployment.yaml', 'r') as opnfvf:
    opnfvcfg = yaml.load(opnfvf)

def setInDict(dataDict, mapList, value):
    getFromDict(dataDict, mapList[:-1])[mapList[-1]] = value

def getFromDict(dataDict, mapList):
    return reduce(lambda d, k: d[k], mapList, dataDict)

if len(labcfg["labconfig"]["nodes"]) < 3:
    print("minimum three nodes are needed for opnfv architecture deployment")
    exit() 

# lets modify the maas general settings:

updns = getFromDict(labcfg, ["labconfig","labsettings","upstream_dns"])
setInDict(opnfvcfg, ["demo-maas", "maas", "settings", "upstream_dns"], updns)
value = getFromDict(labcfg, ["labconfig","lab_location"])
setInDict(opnfvcfg, ["demo-maas", "maas", "settings", "maas_name"], value)
setInDict(opnfvcfg, ["demo-maas", "maas", "name"], "opnfv-"+value)

#lets figure out the interfaces data

ethbrAdm=""
ethbrAdmin=""

c=0
y=0
z=0

while c < len(labcfg["labconfig"]["bridges"]):
    brtype = getFromDict(labcfg, ["labconfig","bridges",c,"type"])
    brname = getFromDict(labcfg, ["labconfig","bridges",c,"bridge"])
    brcidr = getFromDict(labcfg, ["labconfig","bridges",c,"cidr"])
    if brtype == "admin":
        ethbrAdmin = getFromDict(labcfg, ["labconfig","bridges",c,"bridge"])
        brgway = getFromDict(labcfg, ["labconfig","bridges",c,"gateway"])
        tmpcidr = brcidr[:-4]
        setInDict(opnfvcfg, ["demo-maas", "maas", "ip_address"], tmpcidr+"5")
        opnfvcfg["demo-maas"]["maas"]["interfaces"][y] = "bridge="+brname+",model=virtio" 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["device"] = "eth"+str(y) 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["ip"] = tmpcidr+"5" 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["subnet_mask"] = "255.255.255.0" 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["broadcast_ip"] = tmpcidr+"255" 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["router_ip"] = brgway 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["static_range"]["low"] = tmpcidr+"50" 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["static_range"]["high"] = tmpcidr+"80" 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["dynamic_range"]["low"] = tmpcidr+"81" 
        opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["dynamic_range"]["high"] = tmpcidr+"250" 
        opnfvcfg["demo-maas"]["juju-bootstrap"]["interfaces"][z] = "bridge="+brname+",model=virtio" 
        ethbrAdm = ('auto lo\n'
                    '    iface lo inet loopback\n\n'
                    'auto eth'+str(y)+'\n'
                    '    iface eth'+str(y)+' inet static\n'
                    '    address '+tmpcidr+'5\n'
                    '    netmask 255.255.255.0\n'
                    '    gateway '+brgway+'\n'
                    '    dns-nameservers '+updns+' '+tmpcidr+'5 127.0.0.1\n')
        z=z+1
        y=y+1
    elif brtype:
        opnfvcfg["demo-maas"]["maas"]["interfaces"].append("bridge="+brname+",model=virtio")
        brgway = getFromDict(labcfg, ["labconfig","bridges",c,"gateway"])
        if brtype != "external":
            tmpcidr = brcidr[:-4]
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["device"] = "eth"+str(y) 
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["ip"] = tmpcidr+"5" 
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["subnet_mask"] = "255.255.255.0" 
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["broadcast_ip"] = tmpcidr+"255" 
            if brgway:
                opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["router_ip"] = brgway 
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["management"] = 1 
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["static_range"]["low"] = tmpcidr+"20" 
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["static_range"]["high"] = tmpcidr+"150" 
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["dynamic_range"]["low"] = tmpcidr+"151" 
            opnfvcfg["demo-maas"]["maas"]["node_group_ifaces"][y]["dynamic_range"]["high"] = tmpcidr+"200" 
            ethbrAdm  = (ethbrAdm+'\n'
                        'auto eth'+str(y)+'\n'
                        '    iface eth'+str(y)+' inet static\n'
                        '    address '+tmpcidr+'5\n'
                        '    netmask 255.255.255.0\n')
        if brtype == "public":
            opnfvcfg["demo-maas"]["juju-bootstrap"]["interfaces"].append("bridge="+brname+",model=virtio")
            z=z+1
        if brtype == "external":
            ipaddress = getFromDict(labcfg, ["labconfig","bridges",c,"ipaddress"])
            ethbrAdm  = (ethbrAdm+'\n'
                        'auto eth'+str(y)+'\n'
                        '    iface eth'+str(y)+' inet static\n'
                        '    address '+ipaddress+'\n'
                        '    netmask 255.255.255.0\n')
            opnfvcfg["demo-maas"]["juju-bootstrap"]["interfaces"].append("bridge="+brname+",model=virtio")
            z=z+1
        y=y+1


    c=c+1

setInDict(opnfvcfg, ["demo-maas", "maas", "network_config"], ethbrAdm)

# lets modify the maas general settings:
value = get_ip_address(ethbrAdmin) 
value = "qemu+ssh://"+getpass.getuser()+"@"+value+"/system"
setInDict(opnfvcfg, ["demo-maas", "maas", "virsh", "uri"], value)

#lets insert the node details here:
c=0

while c < len(labcfg["labconfig"]["nodes"]):
    # setup value of name and tags accordigly
    value = getFromDict(labcfg, ["labconfig","nodes",c, "type"])
    namevalue = "node" + str(c+1) + "-" + value 
    if c > 0:
        opnfvcfg["demo-maas"]["maas"]["nodes"].append({})

    opnfvcfg["demo-maas"]["maas"]["nodes"][c]["name"] = namevalue
    opnfvcfg["demo-maas"]["maas"]["nodes"][c]["tags"] = value

    # setup value of architecture
    value = getFromDict(labcfg, ["labconfig","nodes",c, "architecture"])
    if value == "x86_64":
        value="amd64/generic"
    opnfvcfg["demo-maas"]["maas"]["nodes"][c]["architecture"] = value
    
    # setup mac_addresses
    value = getFromDict(labcfg, ["labconfig","nodes",c, "pxe_mac_address"])
    opnfvcfg["demo-maas"]["maas"]["nodes"][c]["mac_addresses"] = value
    valuetype = getFromDict(labcfg, ["labconfig","nodes",c, "power", "type"])

    if valuetype == "wakeonlan":
        macvalue = getFromDict(labcfg, ["labconfig","nodes",c, "power", "mac_address"])
        power={"type": "ether_wake", "mac_address": macvalue}
        opnfvcfg["demo-maas"]["maas"]["nodes"][c]["power"] = power
    if valuetype == "ipmi":
        valueaddr = getFromDict(labcfg, ["labconfig","nodes",c, "power", "address"])
        valueuser = getFromDict(labcfg, ["labconfig","nodes",c, "power", "user"])
        valuepass = getFromDict(labcfg, ["labconfig","nodes",c, "power", "pass"])
        valuedriver = "LAN_2_0"
        power={"type": valuetype, "address": valueaddr,"user": valueuser, "pass": valuepass, "driver": valuedriver}
        opnfvcfg["demo-maas"]["maas"]["nodes"][c]["power"] = power


    c=c+1

with open('deployment.yaml', 'w') as opnfvf:
   yaml.dump(opnfvcfg, opnfvf, default_flow_style=False)

