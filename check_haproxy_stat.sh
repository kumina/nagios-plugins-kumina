#!/bin/sh

if test "$#" -ne 1
then
	echo "CRITICAL - usage: $0 server that has to be in UP in HAProxy stats"
	exit 2
fi

echo "show stat" | socat stdio /var/run/haproxy.sock | grep UP | grep -q $1
if [ $? -gt 0 ]
then
	echo "CRITICAL - $1 is not UP"
	exit 2
else
	echo "OK - $1 is UP"
	exit 0
fi
