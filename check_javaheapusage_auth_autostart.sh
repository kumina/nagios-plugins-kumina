#!/bin/sh

if test $# -ne 6
then
	echo "CRITICAL - usage: $0 name_port /path/to/autostart critpercent warnpercent username password"
	exit 2
fi

if [ -f $2 ]; then
	/usr/lib/nagios/plugins/check_javaheapusage_auth $1 $3 $4 $5 $6
else
	echo "OK - Not configured to start"
	exit 0
fi
