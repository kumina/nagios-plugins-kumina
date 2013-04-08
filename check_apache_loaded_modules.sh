#!/bin/sh
#
# This script checks to see if Apache is running with modules not installed from a package.
# This might indicate a break-in.
#
# REQUIREMENTS
# This script requires apache and some common tools and is meant to be run on *nix-systems.
#
# COPYRIGHT
# Copyright 2013 - Kumina B.V./Tim Stoop (tim@kumina.nl), this script is licensed under the
# GNU GPL version 3 or higher.
#

if [ `/usr/bin/whoami` != 'root' ]; then
	echo "You must be root to use this program..."
	exit 3
fi

WARN_AT=0
CRIT_AT=0

while getopts w:c: name
do
	case $name in
	w)
		WARN_AT="$OPTARG"
		;;
	c)
		CRIT_AT="$OPTARG"
		;;
	*)
		echo "usage: $0 [-w num_warning] [-c num_critical]\n" >&2
		exit 1
	esac
done
shift $(($OPTIND - 1))

STATE=4
CRIT_MODULES=''
WARN_MODULES=''
CRIT_NUM=0
WARN_NUM=0
LOADED_SHARED_MODULES=`/usr/sbin/apache2ctl -M 2>/dev/null | /usr/bin/awk '/\(shared\)/ { print $1 }'`
for module in $LOADED_SHARED_MODULES; do
	if [ $STATE -eq 4 ]; then STATE=0; fi
	ON_DISK=`/bin/grep $module /etc/apache2/mods-enabled/*.load | /usr/bin/awk '{ print $NF }'`
	# Check whether we got a response
	if [ "$ON_DISK" != "" ]; then
		IN_PACKAGE=`/usr/bin/dpkg -S $ON_DISK`
		if [ "$IN_PACKAGE" != "" ]; then
			# All is fine
			continue
		else
			CRIT_NUM=$(($CRIT_NUM+1))
			if [ $STATE -lt 2 ] && [ $CRIT_NUM -gt $CRIT_AT ]; then STATE=2; fi
			CRIT_MODULES="$CRIT_MODULES$ON_DISK;"
		fi
	else
		WARN_NUM=$(($WARN_NUM+1))
		if [ $STATE -lt 1 ] && [ $WARN_NUM -gt $WARN_AT ]; then STATE=1; fi
		WARN_MODULES="$WARN_MODULES$module"
	fi
done

if [ $STATE -eq 0 ]; then
	echo 'APACHE OK, no unknown modules found'
	exit 0
elif [ $STATE -eq 1 ]; then
	echo "APACHE WARNING, following modules not found in config: $WARN_MODULES"
	exit 1
elif [ $STATE -eq 2 ]; then
	echo "APACHE CRITICAL, foreign module found: $CRIT_MODULES"
	exit 2
else
	echo "APACHE UNKNOWN, something went wrong"
	exit 3
fi
