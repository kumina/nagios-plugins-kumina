#!/bin/sh
NAME=$1

# Make sure we have input
if [ -z $NAME ]; then
        echo "UNKNOWN: No instance name given"
        exit 3
fi

CACHEFILE=/var/cache/glassfish-list-instances
CACHEDIRNAME=`dirname $CACHEFILE`
CACHEFILENAME=`basename $CACHEFILE`
if [ `find $CACHEDIRNAME -name $CACHEFILENAME -mmin 0.5 | wc -l` -eq 0 ]; then
        # This can take a few seconds, let's use a semaphore to make sure no other process is doing this
        if [ ! -f "${CACHEFILE}.lock" ]; then
                touch "${CACHEFILE}.lock"
                # Run the command to refresh the cache
                su glassfish -c '/opt/glassfish-3.1.2.2/glassfish/bin/asadmin --port 8048 list-instances' > $CACHEFILE
                rm "${CACHEFILE}.lock"
        fi
fi
FULLVALUE=`cat $CACHEFILE | grep -e "^${NAME}\b" | awk '{$1=""; print $0}'`
RUNNING=`echo $FULLVALUE | cut -c1-7`

# Do the actual check
if [ "${RUNNING}" = "running" ]; then
        echo "OK: ${NAME} is$FULLVALUE"
        exit 0
else
        echo "CRITICAL: ${NAME} is not running!"
        exit 2
fi
