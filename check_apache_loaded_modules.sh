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

STATE=4
CRIT_MODULES=''
WARN_MODULES=''
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
			if [ $STATE -lt 2 ]; then STATE=2; fi
			CRIT_MODULES="$CRIT_MODULES$ON_DISK;"
		fi
	else
		if [ $STATE -lt 1 ]; then STATE=1; fi
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
