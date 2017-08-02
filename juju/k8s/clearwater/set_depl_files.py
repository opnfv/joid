'''
Copyright 2017 Aakash KT <aakashkt0@gmail.com> <aakash.kt@research.iiit.ac.in>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
'''

import yaml
import sys
import os

files = ["astaire", "bono", "cassandra", "chronos", "ellis", "etcd", "homer", "homestead",
            "ralf", "sprout"];

try:
    repo = sys.argv[1];
    load_balancer_ip = sys.argv[2];
except:
    print "Usage : python set_depl_files.py <repository_name> <load_balancer_ip>";
    sys.exit(0);

for f in files:

    fp = file("clearwater-docker/kubernetes/%s-depl.yaml"%f, "r+");
    yaml_fp = yaml.load(fp);

    yaml_fp["spec"]["template"]["spec"]["containers"][0]["image"] = "%s/%s:latest" % (repo, f);

    fp.truncate(0);
    fp.seek(0, 0);
    fp.write(yaml.dump(yaml_fp));
    fp.close();

fp = file("clearwater-docker/kubernetes/bono-depl.yaml", "r+");
bono_fp = yaml.load(fp);
bono_depl_env = bono_fp["spec"]["template"]["spec"]["containers"][0]["env"];

for item in bono_depl_env:
    if item["name"] == "PUBLIC_IP":
        item["value"] = load_balancer_ip;

fp.truncate(0);
fp.seek(0, 0);
fp.write(yaml.dump(bono_fp));
fp.close();

fp = file("clearwater-docker/kubernetes/bono-svc.yaml", "r+");
bono_fp = yaml.load(fp);
bono_fp["spec"]["loadBalancerIP"] = load_balancer_ip;
fp.truncate(0);
fp.seek(0, 0);
fp.write(yaml.dump(bono_fp));
fp.close();