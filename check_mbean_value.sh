#!/bin/sh

if test $# -lt 4
then
	echo "CRITICAL - usage: $0 port objectname attributename expectedvalue attributekey"
	exit 2
fi

if test $# -eq 4
then
	CONF="mbean_$1_$3_$4.conf"
else
	CONF="mbean_$1_$3_$4_$5.conf"
fi
java -cp /usr/lib/jmxquery.jar org.munin.JMXQuery --url=service:jmx:rmi:///jndi/rmi://localhost:$1/jmxrmi --conf=/etc/nagios/nrpe.d/$CONF | exec awk "
BEGIN {
	VALUE=-1
}
/^value\.value / {
	VALUE=\$2
}

END {
	if (VALUE == -1) {
		printf \"CRITICAL - Cannot obtain value usage\\n\";
		exit 2
	}

	if (VALUE != $4) {
		printf \"CRITICAL - $3 is %s\n\", VALUE
		exit 2
	} else {
		printf \"OK - $3 is %s\n\", VALUE
		exit 0
	}
}
"
