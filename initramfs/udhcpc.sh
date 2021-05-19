#!/bin/bash
# Configure the IP address
# udhcpc passes the configuration in the environment

if [ "$1" != "bound" ]; then
	exit 0
fi

echo "$interface: $ip router $router"

ifconfig "$interface" "$ip" netmask "$subnet"
route add default gw "$router"
echo "nameserver $dns" > /etc/resolv.conf
