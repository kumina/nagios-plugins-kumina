#!/bin/sh

node=`/bin/hostname`
out="`/usr/sbin/crm node show $node`"
EXIT_OK=0
EXIT_W=1
EXIT_C=2
EXIT_U=3

msg="PACEMAKER STANDBY"

if $(echo "$out" | grep -q 'standby: on'); then
	echo "$msg CRITICAL: $node is in standby"
	exit $EXIT_C
elif $(echo "$out" | grep -q 'standby: off'); then
	echo "$msg OK: $node is not in standby"
	exit $EXIT_OK
else
	echo "$msg UNKNOWN: Cannot get standby status"
	exit $EXIT_U
fi
