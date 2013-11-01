#!/bin/bash
#
# Nagios plugin check_service_status
#
# Version: 1.0, released on 01/11/2013, tested on Debian GNU/Linux 7.0 (wheezy).
#
# This plugin checks status of /etc/init.d scripts.
#
# Copyright (c) 2013 by Rutger Spiertz <rutger@kumina.nl> for Kumina bv.
#
# This work is licensed under the Creative Commons Attribution-Share Alike 3.0
# Unported license. In short: you are free to share and to make derivatives of
# this work under the conditions that you appropriately attribute it, and that
# you only distribute it under the same, similar or a compatible license. Any
# of the above conditions can be waived if you get permission from the copyright
# holder.

# Default exit codes.
OK=0;
WARNING=1;
CRITICAL=2;
UNKNOWN=3;

# Not enough arguments makes no sense.
if [ $# -lt 1 ]; then
	echo "No script to check."
	exit $UNKNOWN
fi

# Check if script exists and is executable.
if [ ! -x "/etc/init.d/$1" ]; then
	echo "Script does not exist or is not executable."
	exit $CRITICAL
fi

# Not being root makes no sense.
if ([ `id -u` != "0" ]); then
	echo "We're a non-privileged user. Not all scripts support that."
	exit $UNKNOWN
fi

# Ask script for status.
RETTEXT=`/etc/init.d/$1 status`
RETVAL=$?

echo $RETTEXT
# Act on certain return values (LSB).
case $RETVAL in
	0)
		exit $OK
	;;
	1)
		exit $CRITICAL
	;;
	2)
		exit $CRITICAL
	;;
	3)
		exit $CRITICAL
	;;
	*)
		echo "Service $1 is unknown."
		exit $UNKNOWN
	;;
esac
