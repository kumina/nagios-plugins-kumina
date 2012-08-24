#!/bin/sh

if test $# -ne 5
then
	echo "CRITICAL - usage: $0 port critpercent warnpercent username password"
	exit 2
fi

# XXX: Backward compatibility!
if test -e $1
then
	$1
else
	echo $1 | grep -q '_'
	if [ $? -eq 0 ]; then # The 'port' is a NAME_PORT combination
		port="`echo $1|awk -F'_' '{print $2}'`"
	else
		port=$1
	fi
	java -cp /usr/lib/jmxquery.jar org.munin.JMXQuery \
		--url=service:jmx:rmi:///jndi/rmi://localhost:$port/jmxrmi \
		--user=$4 \
		--pass=$5 \
		--conf=/usr/share/doc/jmxquery/examples/java/java_process_memory.conf
fi | exec awk "
BEGIN {
	MAX=0
	USED=0
}
/^java_memory_heap_max\.value / {
	MAX=\$2
}
/^java_memory_heap_used\.value / {
	USED=\$2
}

END {
	if (MAX == 0 || USED == 0) {
		printf \"CRITICAL - Cannot obtain memory usage\\n\";
		exit 2
	}

	RATIO = 100 * USED / MAX
	if (RATIO >= $2) {
		printf \"CRITICAL - heap usage is %.2f%%\n\", RATIO
		exit 2
	} else if (RATIO >= $3) {
		printf \"WARNING - heap usage is %.2f%%\n\", RATIO
		exit 1
	} else {
		printf \"OK - heap usage is %.2f%%\n\", RATIO
		exit 0
	}
}
"
