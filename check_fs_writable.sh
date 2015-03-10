#!/bin/bash

PROGNAME=`basename $0`
STAMP=`date +%s`

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
	LOCKERR=`touch /var/lock/$PROGNAME.lock 2>&1`
	if [ $? -ne 0 ]; then
		echo "CRITICAL - could not set lockfile: $LOCKERR"
		exit 2;
	fi
	if [[ -d $DIRNAME ]] && [[ -w $DIRNAME ]]; then
		TOUCHERR=`touch $DIRNAME/.$PROGNAME-$STAMP 2>&1`
		if [ $? -ne 0 ]; then
			rm /var/lock/$PROGNAME.lock
			echo "CRITICAL - cannot touch: $TOUCHERR"
			exit 2;
		fi
		ECHOERR=`echo "$STAMP" > $DIRNAME/.$PROGNAME-$STAMP 2>&1`
		if [ $? -ne 0 ]; then 
			echo "CRITICAL - cannot echo: $ECHOERR"
			rm /var/lock/$PROGNAME.lock
			exit 2;
		fi
		READBACK=`cat "$DIRNAME/.$PROGNAME-$STAMP" 2>&1`
		if [[ $READBACK -ne $STAMP ]]; then
			echo "CRITICAL - read back value is different: $READBACK"
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
