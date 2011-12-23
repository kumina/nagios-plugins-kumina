#!/bin/sh

IPs="`ip add | awk '/inet/ { sub(/\/.*/, "", $2);  print "^" $2 " "}'`"
msg="CASSANDRA"
cassandra_status="$(nodetool ring -h $(hostname) -p 8080 | grep "${IPs}")"

case `echo $cassandra_status | awk '{print $3}'` in
	"Normal")
		msg="${msg} OK:"
		exit_code=0
		;;
	*)
		msg="${msg} CRITICAL:"
		exit_code=2
		;;
esac

msg="${msg} `echo ${cassandra_status} | awk '{print $2,$3}'`"

echo "${msg}"
exit $exit_code
