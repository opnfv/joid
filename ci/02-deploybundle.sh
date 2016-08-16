#!/bin/bash
#placeholder for deployment script.
set -ex

#    ./02-deploybundle.sh $opnfvtype $openstack $opnfvlab $opnfvsdn $opnfvfeature $opnfvdistro

opnfvtype=$1
openstack=$2
opnfvlab=$3
opnfvsdn=$4
opnfvfeature=$5
opnfvdistro=$6

#copy and download charms
cp $opnfvsdn/fetch-charms.sh ./fetch-charms.sh

#modify the ubuntu series wants to deploy
sed -i -- "s|distro=trusty|distro=$opnfvdistro|g" ./fetch-charms.sh

./fetch-charms.sh $opnfvdistro

osdomname=''

#check whether charms are still executing the code even juju-deployer says installed.
check_status() {
    retval=0
    timeoutiter=0
    while [ $retval -eq 0 ]; do
       sleep 30
       juju status > status.txt
       if [ "$(grep -c "executing" status.txt )" -ge 2 ]; then
           echo " still executing the reltionship within charms ..."
           if [ $timeoutiter -ge 60 ]; then
               retval=1
           fi
           timeoutiter=$((timeoutiter+1))
       else
           retval=1
       fi
    done
    echo "...... deployment finishing ......."
}

#read the value from deployment.yaml
if [ -e ~/.juju/deployment.yaml ]; then
   cp ~/.juju/deployment.yaml ./deployment.yaml
   if [ -e ~/.juju/deployconfig.yaml ]; then
      cp ~/.juju/deployconfig.yaml ./deployconfig.yaml
      extport=`grep "ext-port" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //' | tr ',' ' '`
      datanet=`grep "dataNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
      admnet=`grep "admNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
      cephdisk=`grep "ceph-disk" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
      osdomname=`grep "os-domain-name" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
   fi

    workmutiple=`maas maas nodes list | grep "cpu_count" | cut -d ':' -f 2 | sed -e 's/ //' | tr ',' ' '`
    max=0
    for v in ${workmutiple[@]}; do
        if (( $v > $max )); then max=$v; fi;
    done
    echo $max

    if [ "$max" -lt 4 ];then
        workmutiple=1.0
    elif [ "$max" -lt 33 ]; then
        workmutiple=0.25
    elif [ "$max" -lt 73 ]; then
        workmutiple=0.1
    else
        workmutiple=0.05
    fi
    sed -i "s/worker_multiplier: 1/worker_multiplier: ${workmutiple}/g" default_deployment_config.yaml
fi

case "$opnfvlab" in
     'juniperpod1' )
         sed -i -- 's/10.4.1.1/172.16.50.1/g' ./bundles.yaml
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth1"/g' ./bundles.yaml
         ;;
     'ravellodemopod' )
         sed -i -- 's/#ext-port: "eth1"/ext-port: "eth2"/g' ./bundles.yaml
        ;;
esac

# lets put the if seperateor as "," as this will save me from world.
fea=""
IFS=","
for feature in $opnfvfeature; do
    if [ "$fea" == "" ]; then
        fea=$feature
    else
        fea=$fea"_"$feature
    fi
done

#update source if trusty is target distribution
var=os-$opnfvsdn-$fea-$opnfvtype"-"$opnfvdistro"_"$openstack

if [ "$osdomname" != "None" ]; then
    var=$var"_"publicapi
fi

#lets generate the bundle for all target using genBundle.py
python genBundle.py  -l deployconfig.yaml  -s $var > bundles.yaml

echo "... Deployment Started ...."
juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml $opnfvdistro-"$openstack"-nodes

# seeing issue related to number of open files.
# juju run --service nodes 'echo 2048 | sudo tee /proc/sys/fs/inotify/max_user_instances'

count=`juju status nodes --format=short | grep nodes | wc -l`

c=0
while [ $c -lt $count ]; do
    juju ssh nodes/$c 'echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p' || true
    juju ssh nodes-compute/$c 'echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p' || true
    juju ssh nodes/$c 'echo 2048 | sudo tee /proc/sys/fs/inotify/max_user_instances' || true
    juju ssh nodes-compute/$c 'echo 2048 | sudo tee /proc/sys/fs/inotify/max_user_instances' || true
    let c+=1
done

juju-deployer -vW -d -t 7200 -r 5 -c bundles.yaml $opnfvdistro-"$openstack" || true
