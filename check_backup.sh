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
	CONF=${1:-'/etc/backup/offsite-backup.conf'}
	LAST_TIMESTAMP=`/usr/bin/offsite-backup list --config $CONF | /usr/bin/tail -n 1 | /usr/bin/cut -d' ' -f3- | /usr/bin/xargs -i /bin/date -d '{}' +%s`
	if [ $? -gt 0 ]; then
		echo "BACKUP UNKNOWN: List command produces errors"
		exit 4
	fi
	. /etc/backup/offsite-backup.conf
	# This is defaulted in offsite backup script, but we need it here
	listfile=${listfile:-"/tmp/backuplist"}
	# If the last timestamp is empty, error intelligently.
	if [ -z $LAST_TIMESTAMP ]; then
		/bin/rm $listfile
		echo "BACKUP UNKNOWN: Empty response received for status"
		exit 4
	fi
elif [ -f /usr/bin/local-backup ]; then
	LAST_TIMESTAMP=`/usr/bin/local-backup list | /usr/bin/tail -n 1 | /usr/bin/cut -d' ' -f3- | /usr/bin/xargs -i /bin/date -d '{}' +%s`
	if [ $? -gt 0 ]; then
		echo "BACKUP UNKNOWN: List command produces errors"
		exit 4
	fi
	. /etc/backup/local-backup.conf
	# If the last timestamp is empty, error intelligently.
	if [ -z $LAST_TIMESTAMP ]; then
		echo "BACKUP UNKNOWN: Empty response received for status"
		exit 4
	fi
else
	echo "BACKUP UNKNOWN: No known backup solution installed."
	exit 4
fi

# Get current timestamp and calculate the difference
CURRENT_TIMESTAMP=`/bin/date +%s`
DIFFERENCE=$(($CURRENT_TIMESTAMP-$LAST_TIMESTAMP))
READABLE_DIFFERENCE=$(($DIFFERENCE/3600))

# We should allow for this difference
ALLOWANCE=$(((25*3600)+$SPLAY))
CRIT_ALLOWANCE=$((2*$ALLOWANCE))

READABLE_LAST_TIMESTAMP="$(/bin/date -d @${LAST_TIMESTAMP} +'on %b %d %Y at %H:%M (%Z)')"
PERF_DATA="$(/bin/cat /tmp/backuplist | /usr/bin/cut -d' ' -f9- | /usr/bin/head -n-1 | /usr/bin/tail -n+2 | /bin/sed ':a;N;$!ba;s/\n/, /g')"

if [ $DIFFERENCE -gt $CRIT_ALLOWANCE ]; then
	# This is critical!
	echo "BACKUP CRITICAL: Last backup $READABLE_DIFFERENCE hours ago $READABLE_LAST_TIMESTAMP!|$PERF_DATA"
	exit 2
elif [ $DIFFERENCE -gt $ALLOWANCE ]; then
	# Not too critical, let's warn
	echo "BACKUP WARNING: Last backup was $READABLE_DIFFERENCE hours ago $READABLE_LAST_TIMESTAMP.|$PERF_DATA"
	exit 1
else
	# All is fine.
	echo "BACKUP OK: Last backup was $READABLE_DIFFERENCE hours ago $READABLE_LAST_TIMESTAMP.|$PERF_DATA"
	exit 0
fi
