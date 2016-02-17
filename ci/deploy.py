import yaml
import pprint

with open('example.yaml', 'r') as f:
    doc = yaml.load(f)
txt = doc["nodes"][0]["power"]

with open('deployment.yaml', 'r') as ft:
    doc1 = yaml.load(ft)

def setInDict(dataDict, mapList, value):
    getFromDict(dataDict, mapList[:-1])[mapList[-1]] = value

def getFromDict(dataDict, mapList):
    return reduce(lambda d, k: d[k], mapList, dataDict)

if len(doc["nodes"]) > len(doc1["demo-maas"]["maas"]["nodes"]):
    exit 0

c=0
while c < len(doc["nodes"]):

    value = getFromDict(doc, ["nodes",c, "name"])
    setInDict(doc1, ["demo-maas", "maas", "nodes", c, "name"], value)

    value = getFromDict(doc, ["nodes",c, "tags"])
    setInDict(doc1, ["demo-maas", "maas", "nodes", c, "tags"], value)

    value = getFromDict(doc, ["nodes",c, "arch"])
    if value == "x86_64":
        value="amd64/generic"
    setInDict(doc1, ["demo-maas", "maas", "nodes", c, "architecture"], value)

    value = getFromDict(doc, ["nodes",c, "mac_address"])
    setInDict(doc1, ["demo-maas", "maas", "nodes", c, "mac_addresses"], value)

    value = getFromDict(doc, ["nodes",c, "power", "type"])
    setInDict(doc1, ["demo-maas", "maas", "nodes", c, "power", "type"], value)

    if value == "wakeonlan":
        value = getFromDict(doc, ["nodes",c, "power", "mac_address"])
        setInDict(doc1, ["demo-maas", "maas", "nodes", c, "power", "mac_address"], value)

    if value == "ipmi":
        value = getFromDict(doc, ["nodes",c, "power", "address"])
        setInDict(doc1, ["demo-maas", "maas", "nodes", c, "power", "address"], value)

        value = getFromDict(doc, ["nodes",c, "power", "user"])
        setInDict(doc1, ["demo-maas", "maas", "nodes", c, "power", "user"], value)

        value = getFromDict(doc, ["nodes",c, "power", "pass"])
        setInDict(doc1, ["demo-maas", "maas", "nodes", c, "power", "pass"], value)

    c=c+1

with open('deployment.yaml', 'w') as ft:
   yaml.dump(doc1, ft)


