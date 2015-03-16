#!/bin/bash

if [ $# -lt 1 ]; then
	echo "not enough args" >&2; exit 3 ;
elif [ $# -gt 2 ]; then
	echo "too many args" >&2; exit 3;
fi

while getopts ":hp:" FLAG; do
	case "${FLAG}" in
		p)
			PROCNAME=$OPTARG
			;;
		h)
			echo "USAGE: -h, -p to set a proc to check"
			exit 0
			;;
		[:?])
			echo "unknown option"
			echo "USAGE: -h, -p to set a proc to check"
			exit 0
			;;
	esac
done

if [ "$UID" -ne 0 ]; then
	echo "CRITICAL - please exec this as root"
	exit 2
fi

PID=`/bin/pidof $PROCNAME`
if [ $? -ne 0 ]; then
	echo "CRITICAL - could not retrieve PID for $PROCNAME"
	exit 2
fi
if [[ ! -e "/proc/$PID/exe" && -L "/proc/$PID/exe" ]]; then
	echo "CRITICAL - executable for PID $PID ($PROCNAME) is deleted or unexistent"
	exit 2
else
	SYMLINK=`readlink -f /proc/$PID/exe`
	if [ ! -e "$SYMLINK" ]; then
		echo "CRITICAL - executable for PID $PID ($PROCNAME) points to inexistent '$SYMLINK'"
		exit 2
	else
		echo "OK - executable for PID $PID ($PROCNAME) seems alright"
		exit 0
	fi
fi
