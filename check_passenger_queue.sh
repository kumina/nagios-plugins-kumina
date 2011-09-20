#!/bin/sh

quit () {
	echo "Passenger Queue ${1}: There are $currently_waiting waiting request(s), $max_queues maximum queues and $active_queues active queue(s)"
	exit $2
}

usage () {
	echo "Usage: $0 [-w|--warning WARNING_PERCENTAGE] [-c|--critical CRITICAL_PERCENTAGE] [-h|--help]"
	echo "\t-w|--warning WARNING_PERCENTAGE:"
	echo "\t\tThe percentage of waiting requests of the maximum amount of queues, default is 25"
	echo "\t-c|--critical WARNING_PERCENTAGE:"
	echo "\t\tThe percentage of waiting requests of the maximum amount of queues, default is 50"
	echo "\t-h|--help:"
	echo "\t\tShow this help"
}

# Check if the given option is a number
is_number () {
	# is it a number?
	$(expr $1 + 0 > /dev/null 2>&1)
	                 # is it also above 0?
	if [ $? -ne 0 -o $1 -le 0 ];then
		echo "$1 is not a valid percentage"
		exit 3
	else
		return 0
	fi
}

# Set some defaults
W=25
C=50

# Parse options
while [ ! -z $1 ]; do
	case $1 in
	-w|--warning)
		test -z $2 && usage; exit 3
		W=$2
		is_number $W
		shift 2
		;;
	-c|--critical)
		test -z $2 && usage; exit 3
		C=$2
		is_number $C
		shift 2
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		usage
		exit 3
		;;
	esac
done

# Prevent footshooting
if [ $W -ge $C ]; then
	echo "Warning percentage cannot be greater than or equal to Critical percentage" >&2
	exit 3
fi

output=`/usr/sbin/passenger-status`
max_queues=`echo "$output" | /usr/bin/awk '/max/ { print $3 }'`
active_queues=`echo "$output" | /usr/bin/awk '/active/ { print $3 }'| head -1`
currently_waiting=`echo "$output" | /usr/bin/awk '/Waiting on global queue/ { print $5 }'`
percent="$(($currently_waiting / $max_queues * 100))"

if [ $percent -ge $C ]; then
	quit "CRITICAL" 2
elif [ $percent -ge $W ]; then
	quit "WARNING" 1
else
	quit "OK" 0
fi
