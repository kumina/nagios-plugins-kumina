#!/bin/sh

if test $# -ne 4
then
	echo "CRITICAL - usage: $0 /path/to/autostart port url statuscode"
	exit 2
fi

if [ -f $1 ]; then
	/usr/lib/nagios/plugins/check_http_port_url $2 $3 $4
else
	echo "OK - Not configured to start"
	exit 0
fi
