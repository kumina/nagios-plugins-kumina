#!/bin/sh
NAME=$1

# Make sure we have input
if [ -z $NAME ]; then
        echo "UNKNOWN: No instance name given"
        exit 3
fi

FULLVALUE=`su glassfish -c '/opt/glassfish-3.1.2.2/glassfish/bin/asadmin --port 8048 list-instances' | grep -e "^${NAME}\b" | awk '{$1=""; print $0}'`
RUNNING=`echo $FULLVALUE | cut -c1-7`

# Do the actual check
if [ "${RUNNING}" = "running" ]; then
        echo "OK: ${NAME} is$FULLVALUE"
        exit 0
else
        echo "CRITICAL: ${NAME} is not running!"
        exit 2
fi
