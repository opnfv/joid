#!/usr/bin/expect
set MAAS_IP [lindex $argv 0]
spawn dpkg-reconfigure maas-rack-controller -freadline
expect "The MAAS cluster controller and nodes need to contact the MAAS region controller API.  Set the URL at which they can reach the MAAS API remotely, e.g. \"http://192.168.1.1/MAAS\". Since nodes must be able to access this URL, localhost or 127.0.0.1 are not useful values here. Ubuntu MAAS API address:"
send "http://$MAAS_IP:5240/MAAS\r"

# done
expect eof
