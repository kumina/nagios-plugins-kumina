#!/bin/sh
#
# A simple check to see if running ssh processes contain any string that have
# been designated an indication of Fokirtor by Symantec.
#
# More info here:
# http://www.symantec.com/connect/blogs/linux-back-door-uses-covert-communication-protocol
#
# (c) 2013, Kumina bv, info@kumina.nl
#
# You are free to use, modify and distribute this check in any way you see
# fit. Just don't say you wrote it.
#
# This check is created for Debian Squeeze/Wheezy, no idea if it'll work in
# other distros. You'll need gdb-minimal (for gcore) installed.

# We need to be root
if [ `/usr/bin/id -u` -ne 0 ]; then
	echo "You need root for this script. Sorry."
	exit 1
fi

# For all pids of the ssh process, do the check
for pid in `/bin/pidof sshd`; do
        t=$(/bin/mktemp)
        /bin/mv $t $t.$pid

        # call gdb directly, without needing the gcore script from debian-wheezy
        #/usr/local/bin/gcore -o $t $pid >/dev/null
        gdb </dev/null --nx --batch \
          -ex "set pagination off" -ex "set height 0 " \
          -ex "attach $pid" -ex "gcore $t.$pid" -ex detach -ex quit

        for str in hbt= key= dhost= sp= sk= dip=; do
                /usr/bin/strings $t.$pid | /bin/grep "${str}[[:digit:]]"
                if [ $? -eq 0 ]; then
                        echo "CRITICAL: String '${str}' found in sshd process ${pid}!"
                        exit 1
                fi
        done
        /bin/rm $t.$pid
done


echo "OK: No indication of Fokirtor found."
exit 0
