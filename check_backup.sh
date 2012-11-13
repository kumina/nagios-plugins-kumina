#!/bin/sh
#
# Check whether the last backup was completed within the last 24 hours plus the
# allowed splay plus an hour extra for the actual duration of the backup.
#
# Created by: Tim Stoop <info@kumina.nl>, 2012
#

# We need to be root
if [ `/usr/bin/id -u` -ne 0 ]; then
	echo "You need root for this script. Sorry."
	exit 1
fi

# Check if we need to use offsite-backup or local-backup
if [ -f /usr/bin/offsite-backup ]; then
	LAST_TIMESTAMP=`/usr/bin/offsite-backup list | /usr/bin/tail -n 1 | /usr/bin/cut -d' ' -f3- | /usr/bin/xargs -i /bin/date -d '{}' +%s`
	. /etc/backup/offsite-backup.conf
elif [ -f /usr/bin/local-backup ]; then
	LAST_TIMESTAMP=`/usr/bin/local-backup list | /usr/bin/tail -n 1 | /usr/bin/cut -d' ' -f3- | /usr/bin/xargs -i /bin/date -d '{}' +%s`
	. /etc/backup/local-backup.conf
else
	echo "No known backup solution installed."
	exit 1
fi

# Get current timestamp and calculate the difference
CURRENT_TIMESTAMP=`/bin/date +%s`
DIFFERENCE=$(($CURRENT_TIMESTAMP-$LAST_TIMESTAMP))
READABLE_DIFFERENCE=$(($DIFFERENCE/3600))

# We should allow for this difference
ALLOWANCE=$(((25*3600)+$SPLAY))
CRIT_ALLOWANCE=$((2*$ALLOWANCE))

if [ $DIFFERENCE -gt $CRIT_ALLOWANCE ]; then
	# This is critical!
	echo "BACKUP CRITICAL: Last succesful backup was $READABLE_DIFFERENCE hours ago!"
	exit 2
elif [ $DIFFERENCE -gt $ALLOWANCE ]; then
	# Not too critical, let's warn
	echo "BACKUP WARNING: Last succesful backup was $READABLE_DIFFERENCE hours ago."
	exit 1
else
	# All is fine.
	echo "BACKUP OK: Last succesful backup was $READABLE_DIFFERENCE hours ago."
	exit 0
fi
