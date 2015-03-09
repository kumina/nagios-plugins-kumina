#!/bin/bash

PROGNAME=`basename $0`
STAMP=`date +%s`

set -e

if [ $# -lt 1 ]; then
	echo "not enough args" >&2; exit 3 ;
elif [ $# -gt 2 ]; then
	echo "too many args" >&2; exit 3;
fi

while getopts ":hd:" FLAG; do
	case "${FLAG}" in
		d)
			DIRNAME=$OPTARG
			;;
		h)
			echo "USAGE: -h, -d to set a directory to check"
			exit 0
			;;
		[:?])
			echo "unknown option"
			echo "USAGE: -h, -d to set a directory to check"
			exit 0
			;;
	esac
done

if [ ! -f /var/lock/$PROGNAME.lock ]; then
	touch /var/lock/$PROGNAME.lock
	if [[ -d $DIRNAME ]] && [[ -w $DIRNAME ]]; then
		touch $DIRNAME/.$PROGNAME-$STAMP
		if [ $? -ne 0 ]; then
			echo "CRITICAL - cannot touch"
			exit 2;
		fi
		echo "$STAMP" > $DIRNAME/.$PROGNAME-$STAMP 
		if [ $? -ne 0 ]; then 
			echo "CRITICAL - cannot echo"
			exit 2;
		fi
		READBACK=$(cat "$DIRNAME/.$PROGNAME-$STAMP")
		if [[ $READBACK -ne $STAMP ]]; then
			echo "CRITICAL - read back value from file does not correspond with what we set!"
			rm /var/lock/$PROGNAME.lock
			exit 2
		else
			echo "OK - set and read back file on $DIRNAME correctly"
			rm $DIRNAME/.$PROGNAME-$STAMP
			rm /var/lock/$PROGNAME.lock
			exit 0
		fi
	else
		echo "CRITICAL - $DIRNAME is not a directory or not writable"
		rm /var/lock/$PROGNAME.lock
		exit 2
	fi
	rm /var/lock/$PROGNAME.lock
else
	echo "CRITICAL - lock file /var/lock/$PROGNAME.lock is still set; this is bad juju"
	exit 2
fi
