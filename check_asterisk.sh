#!/bin/sh
# Do we have a peer name to check?
if [ -e $1 ]; then
	echo "Please specify the remote peer to check"
	exit 3
fi

msg="Asterisk:"

# Check is asterisk is running
/etc/init.d/asterisk status 2>&1 >/dev/null
if [ $? != 0 ]; then
	echo "${msg} Critical: Asterisk not running"
	exit 2
fi

# Ask asterisk about the status of the peers.
status=$(/usr/sbin/asterisk -rx "sip show registry" | grep "${1}" | awk '{print $4}')

case $status in
Registered)
	echo "Asterisk OK: ${status}"
	exit 0
	;;
*)
	echo "Asterisk Critical: ${status}"
	exit 2
	;;
esac
