#!/usr/bin/expect
set MAAS_IP [lindex $argv 0]
spawn dpkg-reconfigure maas-region-controller -freadline
expect "Ubuntu MAAS PXE/Provisioning network address:"
send "$MAAS_IP\r"

# done
expect eof
