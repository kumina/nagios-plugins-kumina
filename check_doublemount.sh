#!/bin/sh
# check if mountpoints are used more than once

input=/proc/mounts
if [ ! -f $input ]; then
	echo UNKNOWN: $input not readable
	exit 3
fi

# root fs appears twice on every recent Debian system I have seen, so don't report it
output=`awk '{ print $2 }' < ${input} | sort | uniq -c | awk '($1 != "1") && ($2 != "/") { print $2,"mounted",$1,"times "}'`

if echo "$output" | grep -vq '^$'; then
	echo CRITICAL: "$output"
	exit 2
else
	echo OK: no double mounts
	exit 0
fi
