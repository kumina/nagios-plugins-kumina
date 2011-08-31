#!/bin/sh

if test `id -u` -ne 0
then
	echo "$0: needs to be run as root" >&2
	exit 1
fi

rabbitmqctl "$@" list_queues | awk '
/[0-9]$/ {
	if ($2 != 0)
		stuck = stuck " " $1 "[" $2 "]"
}

END {
	if (stuck != "") {
		printf "CRITICAL - stuck messages:%s\n", stuck
		exit 2
	} else {
		printf "OK - all queues are empty\n", stuck
		exit 0
	}
}'
