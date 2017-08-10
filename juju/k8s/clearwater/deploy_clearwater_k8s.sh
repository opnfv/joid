#!/bin/bash

# Copyright 2017 Aakash KT <aakashkt0@gmail.com> <aakash.kt@research.iiit.ac.in>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



function setup_docker() {
	echo "Installing docker..."
	sudo apt-get update
	sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	sudo add-apt-repository \
	   "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	sudo apt-get update
	sudo apt-get install docker-ce

	sudo docker login --username="aakashkt" --password="joid123"
}

function setup_clearwater() {
	echo "Preparing docker images..."

	git clone --recursive https://github.com/Metaswitch/clearwater-docker.git
	pushd clearwater-docker

	for i in base astaire cassandra chronos bono ellis homer homestead ralf sprout
	do
		sudo docker build -t clearwater/$i $i
	done

	for i in base astaire cassandra chronos bono ellis homer homestead ralf sprout
  	do
    	sudo docker tag clearwater/$i:latest $1/$i:latest
    	sudo docker push $1/$i:latest
	done

	popd
}

function setup_k8s() {
	echo "Preparing the k8s cluster..."
	python set_depl_files.py $1 $2
}

function deploy() {
	juju run --application kubeapi-load-balancer 'open-port 5060'

	juju run --application kubernetes-master 'open-port 30080'
	juju run --application kubernetes-worker 'open-port 30080'

	sudo kubectl create -f clearwater-docker/kubernetes
	echo "Done"
}

cp set_depl_files.py /tmp/
pushd /tmp/

juju run --application kubeapi-load-balancer 'unit-get public-address'
load_balancer_ip=$?
docker_repo="aakashkt"

setup_docker
setup_clearwater $docker_repo
setup_k8s $docker_repo $load_balancer_ip
deploy

popd