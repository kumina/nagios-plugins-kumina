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

# Order is important for these two
/usr/sbin/apache2ctl -M 2>/dev/null | /usr/bin/awk '/\(shared\)/ { print $1 }' | /usr/bin/xargs -l -i /bin/grep {} /etc/apache2/mods-enabled/*.load | /usr/bin/awk '{ print $NF }' | /usr/bin/xargs -l /usr/bin/dpkg -S | /bin/grep -q ^dpk
STATUSCODE=`echo $?`

if [ $STATUSCODE -eq 1 ]; then
	echo 'APACHE OK, no unknown modules found'
	exit 0
elif [ $STATUSCODE -eq 0 ]; then
	echo "APACHE CRITICAL, foreign module found: $(/usr/sbin/apache2ctl -M 2>/dev/null | /usr/bin/awk '/\(shared\)/ { print $1 }' | /usr/bin/xargs -l -i /bin/grep {} /etc/apache2/mods-enabled/*.load | /usr/bin/awk '{ print $NF }' | /usr/bin/xargs -l /usr/bin/dpkg -S | /bin/grep ^dpkg)"
	exit 2
else
	echo "APACHE UNKNOWN, something went wrong"
	exit 3
fi
