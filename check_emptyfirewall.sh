#!/bin/sh
# Very naive script to check for an emtpy firewall
# Usage: check_emptyfirewall [-4] [-6]
#  Specify -4 or -6 (or both) for Ipv4 or IPv6; defaults to both

opts=${*:--4 -6}
for opt in $opts; do
	if [ $opt = "-4" ]; then
		if ! iptables-save | grep -q '^-A'; then
			echo CRITICAL: no IPv4 firewall rules
			exit 2
		fi
	elif [ $opt = "-6" ]; then
		if ! ip6tables-save | grep -q '^-A'; then
			echo CRITICAL: no IPv6 firewall rules
			exit 2
		fi
	fi
done
echo OK: there are firewall rules
exit 0
