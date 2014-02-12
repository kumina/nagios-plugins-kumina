#!/bin/sh
#
# Parse a file with key value pairs in it and check if the value for a
# certain key is below a set threshold.
#
# Created by: Tim Stoop <tim@kumina.nl>, 2014
#

input_file=""
warning=0
critical=0
key=""
seperator=" "

while getopts "h?w:c:f:k:s:" opt; do
	case "$opt" in
	h|\?)
		echo "Usage: $0 [-w threshold] [-c threshold] [-s separator] -f filename -k key"
		exit 0
		;;
	w)
		warning=$OPTARG
		;;
	c)
		critical=$OPTARG
		;;
	f)
		input_file=$OPTARG
		;;
	k)
		key=$OPTARG
		;;
	s)
		seperator=$OPTARG
		;;
	esac
done

# We require a filename
if [ -z $input_file ]; then echo "Filename required. Try -h."; exit 4; fi
# And a key
if [ -z $key ]; then echo "Key required. Try -h."; exit 4; fi
# File must exist.
if [ ! -r $input_file ]; then echo "File does not exist or is not readable by $(whoami)!"; exit 4; fi

value=`/bin/grep "^$key" $input_file | /usr/bin/cut -d"$seperator" -f2`
value=`printf '%f' "$value"`

# We didn't get a value
if [ $? -gt 0 ] || [ -z $value ]; then echo "No value found!"; exit 4; fi

if [ `/bin/echo "$value > $critical" | /usr/bin/bc -q` -gt 0 ]; then
	echo "CRITICAL: value $value higher than $critical"
	exit 2
elif [ `/bin/echo "$value > $warning" | /usr/bin/bc -q` -gt 0 ]; then
	echo "WARNING: value $value higher than $warning, but still below $critical"
	exit 1
else
	# All is fine.
	echo "OK: value $value below $warning"
	exit 0
fi
