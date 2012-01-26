#!/bin/sh

if test "$#" -ne 1
then
	echo "CRITICAL - usage: $0 filename"
	exit 2
fi

if ferm -n $1 > /dev/null 2>&1
then
	echo "OK - $1 parsed successfully"
	exit 0
else
	echo "CRITICAL - failed to parse $1"
	exit 2
fi
