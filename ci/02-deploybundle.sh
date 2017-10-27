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
opnfvmodel=$7

if [[ "$opnfvmodel" = "openstack" ]]; then
    #copy and download charms
    ./$opnfvsdn/fetch-charms.sh $opnfvdistro
    osdomname=''
else
    ./kubernetes/fetch-charms.sh $opnfvdistro
fi

#check whether charms are still executing the code even juju-deployer says installed.
check_status() {
    waitstatus=$1
    waittime=$2
    retval=0
    timeoutiter=0

    echo -n "executing the reltionship within charms ."
    while [ $retval -eq 0 ]; do
        if juju status | grep -q $waitstatus; then
           echo -n '.'
           if [ $timeoutiter -ge $waittime ]; then
               echo 'timed out'
               retval=1
           else
               sleep 30
           fi
           timeoutiter=$((timeoutiter+1))
       else
           echo 'done'
           retval=1
       fi
    done
    echo "...... deployment finishing ......."
}

#read the value from deployconfig.yaml

PROFILE=maas
MAAS_IP=$(grep " ip_address" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //')
API_SERVERMAAS="http://$MAAS_IP:5240/MAAS/"
API_KEY=`sudo maas-region apikey --username=ubuntu || true`

if [[ "$API_KEY" = "" ]]; then
    API_KEY=`sshpass -p ubuntu ssh ubuntu@$MAAS_IP 'sudo maas-region apikey --username=ubuntu'`
fi

maas login $PROFILE $API_SERVERMAAS $API_KEY

if [[ "$opnfvmodel" = "openstack" ]]; then
    if [ -e ./deployconfig.yaml ]; then
       extport=`grep "ext-port" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //' | tr ',' ' '`
       datanet=`grep "dataNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
       admnet=`grep "admNetwork" deployconfig.yaml | cut -d ' ' -f 4 | sed -e 's/ //'`
       cephdisk=`grep "ceph-disk" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
       osdomname=`grep "os-domain-name" deployconfig.yaml | cut -d ':' -f 2 | sed -e 's/ //'`
    fi

    workmutiple=`maas maas nodes read | grep "cpu_count" | cut -d ':' -f 2 | sed -e 's/ //' | tr ',' ' '`
    max=0
    for v in ${workmutiple[@]}; do
        if (( $v > $max )); then max=$v; fi;
    done
    echo $max

    if [ "$max" -lt 4 ];then
        workmutiple=1.1
    elif [ "$max" -lt 33 ]; then
        workmutiple=0.25
    elif [ "$max" -lt 73 ]; then
        workmutiple=0.1
    else
        workmutiple=0.05
    fi
    sed -i "s/worker_multiplier: 1.0/worker_multiplier: ${workmutiple}/g" default_deployment_config.yaml

    if [ "$opnfvlab" != "default" ]; then
        sed -i "s/cpu_pin_set: all/cpu_pin_set: 2-${max},^${max}/g" default_deployment_config.yaml
    else
        sed -i "s/cpu_pin_set: all/cpu_pin_set: 1/g" default_deployment_config.yaml
    fi
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

# lets put the if separator as "," as this will save me from world.
fea=""
IFS=","
for feature in $opnfvfeature; do
    if [ "$fea" == "" ]; then
        fea=$feature
    else
        fea=$fea"_"$feature
    fi
done

if [[ "$opnfvmodel" = "openstack" ]]; then
    #update source if trusty is target distribution
    var=os-$opnfvsdn-$fea-$opnfvtype"-"$opnfvdistro"_"$openstack

else
    var=k8-$opnfvsdn-$fea-baremetal-core
fi

if [[ "$opnfvmodel" = "openstack" ]]; then
    #lets generate the bundle for all target using genBundle.py
    python genBundle.py  -l deployconfig.yaml  -s $var > bundles.yaml
else
    #lets generate the bundle for k8 target using genK8Bundle.py
    python genK8Bundle.py  -l deployconfig.yaml  -s $var > bundles.yaml
fi

#keep the back in cloud for later debugging.
pastebinit bundles.yaml || true

# with JUJU 2.0 bundles has to be deployed only once.
juju deploy bundles.yaml --debug
sleep 720
check_status allocating 220

# need to revisit later if not needed we will remove the below.
openfile_fix() {
    # seeing issue related to number of open files.
    count=`juju status nodes --format=short | grep nodes | wc -l`
    c=0
    while [ $c -lt $count ]; do
        juju ssh nodes/$c 'echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p' || true
        juju ssh nodes-compute/$c 'echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p' || true
        juju ssh nodes/$c 'echo 2048 | sudo tee /proc/sys/fs/inotify/max_user_instances' || true
        juju ssh nodes-compute/$c 'echo 2048 | sudo tee /proc/sys/fs/inotify/max_user_instances' || true
        let c+=1
    done
}

if [ "$opnfvsdn" = "ocl" ]
then
  TAG="ubuntu16.04-4.0.1.0-32.tar.gz"

  for ROLE in contrail-controller contrail-analytics contrail-analyticsdb
  do
    FILE="${ROLE}-${TAG}"
  if [ ! -f $FILE ]
  then
    curl -o $FILE http://artifacts.opnfv.org/ovno/containers/$FILE
  fi
  juju attach $ROLE ${ROLE}="./$FILE"
done
fi
#lets gather the status of deployment once juju-deployer completed.
juju status --format=tabular
