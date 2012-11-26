#!/bin/sh

IPs="`ip add | awk '/inet/ { sub(/\/.*/, "", $2);  print "^" $2 " "}'`"
msg="CASSANDRA"
cassandra_status="$(/usr/bin/nodetool ring -h $(hostname) -p 7199 | grep "${IPs}")"

cassandra_major_version=`/usr/bin/dpkg -l cassandra | /usr/bin/awk '{ if ($1 ~/^ii/) { print $3 } }' | /usr/bin/cut -c 1-1`

if [ $cassandra_major_version -lt 1 ]; then
	case `echo $cassandra_status | /usr/bin/awk '{print $3}'` in
		"Normal")
			msg="${msg} OK:"
			exit_code=0
			;;
		*)
			msg="${msg} CRITICAL:"
			exit_code=2
			;;
	esac
	msg="${msg} `echo ${cassandra_status} | /usr/bin/awk '{print $2,$3}'`"
else
	case `echo $cassandra_status | /usr/bin/awk '{print $5}'` in
		"Normal")
			msg="${msg} OK:"
			exit_code=0
			;;
		*)
			msg="${msg} CRITICAL:"
			exit_code=2
			;;
	esac
	msg="${msg} `echo ${cassandra_status} | /usr/bin/awk '{print $4,$5}'`"
fi

echo "${msg}"
exit $exit_code
