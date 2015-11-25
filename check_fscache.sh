#!/bin/sh
if [ -z $1 ]; then
        /bin/echo "Usage: check_fscache DIR, where DIR is the fscache directory."
        exit 3
fi

# Get the mountpoint where the supplied path is mounted
MOUNTPOINT=`/bin/df "${1}"  | /usr/bin/tail -1 | /usr/bin/awk '{ print $NF }'`
# Check whether the mount has the user_xattr option enabled
USERXATTR_ENABLED=`/bin/mount -l | /bin/grep "on ${MOUNTPOINT}" | /bin/grep -c 'user_xattr'`

if [ "$USERXATTR_ENABLED" -gt 0 ]; then
        /bin/echo "OK: mountpoint ${MOUNTPOINT} has user_xattr enabled."
        exit 0
else
        /bin/echo "CRITICAL: mountpoint ${MOUNTPOINT} does not have user_xattr enabled, but this is required for FS-Cache."
        exit 2
fi
