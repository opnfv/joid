#!/bin/bash
##############################################################################
# Copyright (c) 2017 Nokia and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
# A script to create virtual hosts in Apache2 to proxy communication
# to the web dashboards/consoles which might be on private networks. In case
# of frequent access to these services, this approach is simpler than using
# SSH tunneling each time.
# Additionally, this script creates a customized homepage for the jumphost
# with links to the dashboards and information about the credentials.
#
# Note that this script is meant for test deployments and might pose
# security risks for other uses (the SSL certificates are not validated,
# passwords are displayed in plaintext etc).
#
# Usage: ./setupproxy.sh [-v] openstack
#        ./setupproxy.sh [-v] kubernetes
#        ./setupproxy.sh --help
# Options:
#   -v   verbose (xtrace)
#
# Author: Martin Kulhavy
##############################################################################

# Imports
source tools.sh

# Halt on error
set -e

# CONFIGURATION

## JOID
JOID_CONFIG_DIR=../../joid_config

## Apache config directories
A2_DIR=/etc/apache2
A2_SSL_DIR=$A2_DIR/ssl/joid
A2_SITES_ENABLED_DIR=$A2_DIR/sites-enabled

## Juju
JUJU_LOCAL_PORT=17070

## OpenStack
OS_LOCAL_PORT=17080
OS_LOCAL_PORT_SSL=17443

# Kubernetes
KUBE_LOCAL_PORT=17080

# end of CONFIGURATION

# Other global vars
VERBOSE=false
MAAS_WUI_PATH='/MAAS'
MAAS_CREDENTIALS=('ubuntu' 'ubuntu')
SETUP_JUJU=true
SETUP_OPENSTACK=false
SETUP_KUBERNETES=false
JUJU_GUI_PATH='/gui'
JUJU_GUI_CREDENTIALS=()
OS_DB_CREDENTIALS=()
KUBE_DB_PATH='/ui'
KUBE_DB_CREDENTIALS=()
EXTERNAL_HOST=jumphost


# Print out usage information and exit.
# $1 - exit code [optional, default 0]
usage() {
    # no xtrace output
    { set +x; } 2> /dev/null

    echo "Usage: $0 [-v] openstack"
    echo "       $0 [-v] kubernetes"
    echo "       $0 --help"
    echo "Options:"
    echo "  -v   verbose (xtrace)"
    echo ""
    echo "Sets up Apache proxy to the Juju and OpenStack or Kubernetes "
    echo "dashboards, so that they are accessible through the jumphost, "
    echo "even when on private networks."
    exit ${1-0}
}

# Parse the arguments of the script
# $@ - script arguments
parse_args() {
    # Print usage help message if requested
    if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
    fi

    # Parse args
    if [ "-v" = "$1" ]; then
        VERBOSE=true
        shift
        set -x
    fi

    if [ "openstack" = "$1" ]; then
        SETUP_OPENSTACK=true
    elif [ "kubernetes" = "$1" ]; then
        SETUP_KUBERNETES=true
    else
        usage 1
    fi
}


# Get a value from a script exporting variables, i.e. consisting of lines
# in format `export VAR=value`.
# $1 - filename
# $2 - variable name
get_export_var_value() {
    value=$(cat $1 | grep -Px "export $2=.+" | cut -d '=' -f 2)
    echo "$value"
}


# Attempt to find the external IP address.
# Takes the source address for traffic on default route.
get_external_ip() {
    # Look for the source IP when trying to request outside address
    ext_ip=$(ip route get 8.8.8.8 | awk '/src/{print $7}')
    if [ -n "ext_ip" ]; then
        EXTERNAL_HOST=$ext_ip
    fi
}


# Enable Apache mods needed for the proxy.
enable_mods() {
    sudo a2enmod proxy
    sudo a2enmod proxy_http
    sudo a2enmod rewrite
    sudo a2enmod deflate
    sudo a2enmod headers
    sudo a2enmod ssl
}


# Generate SSL keys and certificate to allow serving content over https.
generate_ssl_keys_cert() {
    if [ ! -e $A2_SSL_DIR ]; then
        sudo mkdir -p $A2_SSL_DIR
    fi
    sudo openssl genrsa -out $A2_SSL_DIR/ca.key 2048
    sudo openssl req -nodes -new \
        -subj "/C=OS/ST=None/L=None/O=OS/CN=localhost" \
        -key $A2_SSL_DIR/ca.key -out $A2_SSL_DIR/ca.csr
    sudo openssl x509 -req -days 365 \
        -in $A2_SSL_DIR/ca.csr -signkey $A2_SSL_DIR/ca.key \
        -out $A2_SSL_DIR/ca.crt
}


# Remove the Apache configuration file for the default virtual host.
remove_default_site() {
    def_site_conf=$A2_SITES_ENABLED_DIR/000-default.conf
    if [ -e $def_site_conf ]; then
        sudo rm $def_site_conf
    fi
}


# Add a port for Apache to listen on. Only added if not yet present
# $1 - port number
add_listening_port() {
    if [ -z "$1" ]; then
        echo_error "No port to add specified"
        exit 1
    fi

    # Add the port only if not already added
    if [ $(cat $A2_DIR/ports.conf | grep -Fx "Listen $1" | wc -l) -eq 0 ]; then
        echo "Listen $1" | sudo tee -a $A2_DIR/ports.conf
    fi
}


# Setup a proxy for requests to the Juju GUI.
setup_juju_gui_proxy() {
    # Get Juju GUI info
    juju_gui_info=$(juju gui 2>&1)
    juju_gui_url=$(echo "$juju_gui_info" | grep -Po 'https://[^\s]+')
    juju_socket=$(echo "$juju_gui_url" | grep -Po 'https://\K[^/]+')
    JUJU_GUI_PATH=$(echo "$juju_gui_url" | grep -Po 'https://[^/]+\K/.+')
    juju_gui_username=$(echo "$juju_gui_info" | grep -Po 'username: .+' \
                                                | cut -d ' ' -f 2)
    juju_gui_password=$(echo "$juju_gui_info" | grep -Po 'password: .+' \
                                                | cut -d ' ' -f 2)
    JUJU_GUI_CREDENTIALS=("$juju_gui_username" "$juju_gui_password")

    # Virtual host settings
    sudo tee "${A2_DIR}/sites-enabled/juju-gui.conf" > /dev/null <<-EOF
		<VirtualHost *:${JUJU_LOCAL_PORT}>
		    ServerName localhost
		    ServerAlias *
		    SSLEngine On
		    SSLCertificateFile ${A2_SSL_DIR}/ca.crt
		    SSLCertificateKeyFile ${A2_SSL_DIR}/ca.key
		    RewriteEngine On
		    RewriteCond %{HTTP:Connection} Upgrade [NC]
		    RewriteCond %{HTTP:Upgrade} websocket [NC]
		    RewriteRule /(.*) wss://${juju_socket}/\$1 [P,L]
		    SSLProxyEngine on
		    SSLProxyVerify none
		    SSLProxyCheckPeerCN off
		    SSLProxyCheckPeerName off
		    SSLProxyCheckPeerExpire off
		    ProxyPass / https://${juju_socket}/
		    ProxyPassReverse / https://${juju_socket}/
		</VirtualHost>
EOF

    # Add the local port to listen on
    add_listening_port ${JUJU_LOCAL_PORT}
}


# Setup a proxy for requests to the OpenStack dashboard.
setup_openstack_dashboard_proxy() {
    # Get OpenStack dashboard info
    os_ip=$(juju status | awk '/openstack-dashboard\/0/ {print $5}')
    if [ -z "$os_ip" ]; then
        echo_error "Unable to find unit openstack-dashboard/0. Is this an OpenStack deployment?"
        exit 1
    fi

    # Virtual host settings
    sudo tee "${A2_DIR}/sites-enabled/openstack-dashboard.conf" > /dev/null \
        <<-EOF
		<VirtualHost *:${OS_LOCAL_PORT}>
		    ServerName localhost
		    ServerAlias *
		    ProxyPass / http://${os_ip}/
		    ProxyPassReverse / http://${os_ip}/
		</VirtualHost>
		<VirtualHost *:${OS_LOCAL_PORT_SSL}>
		    ServerName localhost
		    ServerAlias *
		    SSLEngine On
		    SSLCertificateFile ${A2_SSL_DIR}/ca.crt
		    SSLCertificateKeyFile ${A2_SSL_DIR}/ca.key
		    SSLProxyEngine on
		    SSLProxyVerify none
		    SSLProxyCheckPeerCN off
		    SSLProxyCheckPeerName off
		    SSLProxyCheckPeerExpire off
		    ProxyPass / https://${os_ip}/
		    ProxyPassReverse / https://${os_ip}/
		</VirtualHost>
EOF

    # Add the local ports to listen on
    add_listening_port ${OS_LOCAL_PORT}
    add_listening_port ${OS_LOCAL_PORT_SSL}

    # Collect login credentials
    openrc=${JOID_CONFIG_DIR}/admin-openrc
    OS_DB_CREDENTIALS[0]=$(get_export_var_value $openrc 'OS_USERNAME')
    OS_DB_CREDENTIALS[1]=$(get_export_var_value $openrc 'OS_PASSWORD')
    OS_DB_CREDENTIALS[2]=$(get_export_var_value $openrc 'OS_USER_DOMAIN_NAME')
}


# Attempt to start the Kubernetes Web UI (Dashboard)
start_kubernetes_dashboard() {
    # See docs: https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/

    machine_num=$(juju status | awk '/kubernetes-master\/0/ {print $4}')
    if [ -z "$machine_num" ]; then
        echo_error "Unable to find unit kubernetes-master/0. Is this a Kubernetes deployment?"
        exit 1
    fi

    echo "Attempting to start Kubernetes Web UI proxy. A timeout error can be expected here."
    juju run --machine="$machine_num" --timeout=5s "kubectl proxy --address='' --accept-hosts='' &" || true
}


# Setup a proxy for requests to the Kubernetes dashboard.
setup_kubernetes_dashboard_proxy() {

    # Get Kubernetes master ip (where dashboard is running)
    kube_ip=$(juju status | awk '/kubernetes-master\/0/ {print $5}')
    # Note: Maybe the port discovery can be automated. Port 8001 is default.
    kube_socket="$kube_ip:8001"

    # Virtual host settings
    sudo tee "${A2_DIR}/sites-enabled/kubernetes-dashboard.conf" > /dev/null \
        <<-EOF
		<VirtualHost *:${KUBE_LOCAL_PORT}>
		    ServerName localhost
		    ServerAlias *
		    ProxyPass / http://${kube_socket}/
		    ProxyPassReverse / http://${kube_socket}/
		</VirtualHost>
EOF

    # Add the local port to listen on
    add_listening_port ${KUBE_LOCAL_PORT}
}


print_info_message() {
    # no xtrace output
    { set +x; } 2> /dev/null

    echo ''
    echo_info -n "JOID deployment overview page";
    echo    " is now accessible on the following url (jumphost):"
    echo -n "  Address:  "; echo_info "http://${EXTERNAL_HOST}/"
    echo ''

    if [ "$SETUP_JUJU" = true ]; then
        echo_info -n "Juju GUI";
        echo    " is now accessible with the following url and credentials:"
        echo -n "  Address:  "; echo_info "https://${EXTERNAL_HOST}:${JUJU_LOCAL_PORT}${JUJU_GUI_PATH}"
        echo -n "  Username: "; echo_info "${JUJU_GUI_CREDENTIALS[0]}"
        echo -n "  Password: "; echo_info "${JUJU_GUI_CREDENTIALS[1]}"
        echo ''
    fi
    if [ "$SETUP_OPENSTACK" = true ]; then
        echo_info -n "OpenStack dashboard"
        echo    " is now accessible with the following url and credentials:"
        echo -n "  Address:   "; echo_info -n "https://${EXTERNAL_HOST}:${OS_LOCAL_PORT_SSL}/";
        echo -n " or ";          echo_info    "http://${EXTERNAL_HOST}:${OS_LOCAL_PORT}/"
        echo -n "  Domain:    "; echo_info    "${OS_DB_CREDENTIALS[2]}"
        echo -n "  User Name: "; echo_info    "${OS_DB_CREDENTIALS[0]}"
        echo -n "  Password:  "; echo_info    "${OS_DB_CREDENTIALS[1]}"
        echo ''
    fi
    if [ "$SETUP_KUBERNETES" = true ]; then
        echo_info -n "Kubernetes dashboard"
        echo    " is now accessible with the following url and credentials:"
        echo -n "  Address:   "; echo_info "http://${EXTERNAL_HOST}:${KUBE_LOCAL_PORT}${KUBE_DB_PATH}";
        echo    "  No credentials needed if started on kubernetes-master/0 with command:"
        echo    "    kubectl proxy --address='' --accept-hosts='' &"
        echo ''
    fi

}


# Create a homepage for the jumphost with links to the dashboards
create_homepage() {
    # Note: If this function is about to get any more complicated,
    # it might be worth using template rendering instead.

    juju_origin="10.21.19.100:17070"
    juju_url="https://10.21.19.100:17070/gui/u/admin/default"
    os_origin="https://10.21.19.100:17443/"
    os_url="10.21.19.100:17443"
    kube_origin="https://10.21.19.100:17443/"
    kube_url="10.21.19.100:17443"

    sudo tee "/var/www/html/index.html" > /dev/null <<EOF
		<!doctype html>
		<html lang="en">
		<head>
		  <meta charset="utf-8">
		  <title>OPNFV - deployed with JOID</title>
		  <script src="https://cdn.rawgit.com/zenorocha/clipboard.js/v1.7.1/dist/clipboard.min.js"></script>
		  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/normalize/7.0.0/normalize.css" />
		  <style>
		    body { text-align: center; padding-top: 15%; line-height: 1.3;
		           font-size: 14pt; font-family: Helvetica, Arial, sans-serif;
		           color: #383a35; }
		    * { box-sizing: border-box; }
		    #logo { max-width: 600px; margin: auto; }
		    fieldset { display: inline-block; width: 400px; min-height: 150pt;
		               text-align: center; border: 2px solid #383a35;
		               vertical-align: top; }
		    legend { font-size: 16pt; font-weight: bold; padding: 0 5pt; }
		    table { width: 100%; }
		    a { font-weight: bold; text-decoration: none; display: block;
		        padding: 5px; margin: 10px; }
		    a:hover, a:active { background-color: #eef; }
		    th { width: 40%; text-align: right; }
		    td { width: 60%; text-align: left;  }
		    input { width: 170px; height: 16pt; color: #000; background: #fff;
		            border: 1px solid #ddd; vertical-align: bottom; }
		    button.copy { width: 16pt; height: 16pt; vertical-align: bottom;
		                  background: white url('https://cdnjs.cloudflare.com/ajax/libs/octicons/4.4.0/svg/clippy.svg') no-repeat center; }
		    p { font-size: 12pt; text-align: left; }
		    pre { font-size: 10pt }
		  </style>
		</head>
		<body>
		  <img src="https://www.opnfv.org/wp-content/uploads/sites/12/2016/11/opnfv_logo_wp.png"
		       id="logo" alt="OPNFV logo" />
		  <h1>Deployed with JOID</h1>
EOF

    # MAAS info box
    origin="${EXTERNAL_HOST}:80"
    url="http://${origin}${MAAS_WUI_PATH}"
    user="${MAAS_CREDENTIALS[0]}"
    pass="${MAAS_CREDENTIALS[1]}"
    sudo tee -a "/var/www/html/index.html" > /dev/null <<EOF
		  <fieldset><legend>MAAS dashboard</legend>
		    <a href="${url}" target="_blank" title="Open MAAS dashboard">${origin}</a>
		    <table><tr><th>Username:</th><td><input type="text" id="maas-user" value="${user}"
		               /><button class="copy" data-clipboard-target="#maas-user"></button></td></tr>
		           <tr><th>Password:</th><td><input type="text" id="maas-pass" value="${pass}"
		               /><button class="copy" data-clipboard-target="#maas-pass"></button></td></tr>
		    </tbody></table>
		  </fieldset>
EOF

    if [ "$SETUP_JUJU" = true ]; then
        origin="${EXTERNAL_HOST}:${JUJU_LOCAL_PORT}"
        url="https://${origin}${JUJU_GUI_PATH}"
        user="${JUJU_GUI_CREDENTIALS[0]}"
        pass="${JUJU_GUI_CREDENTIALS[1]}"
        sudo tee -a "/var/www/html/index.html" > /dev/null <<EOF
		  <fieldset><legend>Juju GUI</legend>
		    <a href="${url}" target="_blank" title="Open Juju GUI">${origin}</a>
		    <table><tr><th>Username:</th><td><input type="text" id="juju-user" value="${user}"
		               /><button class="copy" data-clipboard-target="#juju-user"></button></td></tr>
		           <tr><th>Password:</th><td><input type="text" id="juju-pass" value="${pass}"
		               /><button class="copy" data-clipboard-target="#juju-pass"></button></td></tr>
		    </table>
		  </fieldset>
EOF
    fi

    if [ "$SETUP_OPENSTACK" = true ]; then
        origin="${EXTERNAL_HOST}:${OS_LOCAL_PORT_SSL}"
        url="https://${origin}/"
        user="${OS_DB_CREDENTIALS[0]}"
        pass="${OS_DB_CREDENTIALS[1]}"
        domain="${OS_DB_CREDENTIALS[2]}"
        sudo tee -a "/var/www/html/index.html" > /dev/null <<EOF
		  <fieldset><legend>OpenStack dashboard</legend>
		    <a href="${url}" target="_blank" title="Open OpenStack dashboard">${origin}</a>
		    <table><tr><th>Domain:</th><td><input type="text" id="os-domain" value="${domain}"
		               /><button class="copy" data-clipboard-target="#os-domain"></button></td></tr>
		           <tr><th>User Name:</th><td><input type="text" id="os-user" value="${user}"
		               /><button class="copy" data-clipboard-target="#os-user"></button></td></tr>
		           <tr><th>Password:</th><td><input type="text" id="os-pass" value="${pass}"
		               /><button class="copy" data-clipboard-target="#os-pass"></button></td></tr>
		    </table>
		  </fieldset>
EOF
    fi

    if [ "$SETUP_KUBERNETES" = true ]; then
        origin="${EXTERNAL_HOST}:${KUBE_LOCAL_PORT}"
        url="http://${origin}${KUBE_DB_PATH}"
        user="${KUBE_DB_CREDENTIALS[0]}"
        pass="${KUBE_DB_CREDENTIALS[1]}"
        sudo tee -a "/var/www/html/index.html" > /dev/null <<EOF
		  <fieldset><legend>Kubernetes dashboard</legend>
		    <a href="${url}" target="_blank" title="Open Kubernetes dashboard">${origin}</a>
		    <div>
		      <p>No credentials needed if started with command</p>
		      <pre>kubectl proxy --address='' --accept-hosts='' &</pre>
		    </div>
		  </fieldset>
EOF
    fi

    sudo tee -a "/var/www/html/index.html" > /dev/null <<EOF
		  <script>new Clipboard('button.copy');</script>
		</body>
		</html>
EOF
}


main() {
    # Do not run script as root (causes later permission issues with Juju)
    if [ "$(id -u)" == "0" ]; then
        echo_error "Must not be run with sudo or by root"
        exit 77
    fi

    parse_args "$@"

    get_external_ip

    echo_info "Enabling Apache mods"
    enable_mods

    echo_info "Generating SSL keys and certificates"
    generate_ssl_keys_cert

    remove_default_site

    if [ "$SETUP_JUJU" = true ]; then
        echo_info "Setting up proxy configuration for Juju GUI"
        setup_juju_gui_proxy
    fi
    if [ "$SETUP_OPENSTACK" = true ]; then
        echo_info "Setting up proxy configuration for OpenStack dashboard"
        setup_openstack_dashboard_proxy
    fi
    if [ "$SETUP_KUBERNETES" = true ]; then
        echo_info "Starting Kubernetes dashboard"
        start_kubernetes_dashboard
        echo_info "Setting up proxy configuration for Kubernetes dashboard"
        setup_kubernetes_dashboard_proxy
    fi

    echo_info "Creating the homepage for jumphost"
    create_homepage


    echo_info "Restarting HTTP server"
    sudo service apache2 restart

    # Print info message
    echo_info "Setup finished."
    print_info_message
}

# Start the script with the main() function
main "$@"
