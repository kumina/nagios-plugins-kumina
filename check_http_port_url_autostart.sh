#!/bin/sh

if test $# -ne 4
then
	echo "CRITICAL - usage: $0 /path/to/autostart port url statuscode"
	exit 2
fi

if [ -f $1 ]; then
	/usr/lib/nagios/plugins/check_http -H 127.0.0.1 -p $2 -u $3 -e $4 -t 20
else
	echo "OK - Not configured to start"
	exit 0
fi
