#!/bin/bash
#
# Nagios plugin check_proc_status.sh
#
# Version: 1.0, released on 10/08/2010, tested on Debian GNU/Linux 5.0 (lenny).
#
# This plugin checks status of /etc/init.d scripts.
#
# Copyright (c) 2010 by Kees Meijs <kees@kumina.nl> for Kumina bv.
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
if [ ${#} -lt 1 ]; then
        echo "No script to check."
        exit ${UNKNOWN}
fi

# Check if script exists and is executable.
if [ ! -x "/etc/init.d/${1}" ]; then
	echo "Script does not exist or is not executable."
	exit ${CRITICAL}
fi

# Not being root makes no sense.
if ([ `id -u` != "0" ]); then
        echo "We're a non-privileged user. Not all scripts support that."
        exit ${UNKNOWN}
fi

# Ask script for status.
/etc/init.d/${1} status &> /dev/null
RETVAL=${?}

# Act on certain return values (LSB).
case ${RETVAL} in
	0)
		echo "Service ${1} OK."
		exit ${OK}
	;;
	1)
		echo "Service ${1} is dead but /var/run PID file exists."
		exit ${CRITICAL}
	;;
	2)
		echo "Service ${1} is dead but /var/lock lock file exists."
		exit ${CRITICAL}
	;;
	3)
		echo "Service ${1} is not running."
		exit ${CRITICAL}
	;;
	*)
		echo "Service ${1} is unknown."
		exit ${UNKNOWN}
	;;
esac
