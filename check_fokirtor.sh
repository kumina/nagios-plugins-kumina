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
        /usr/bin/gdb </dev/null --nx --batch \
          -ex "set pagination off" -ex "set height 0 " -ex "set width 0" \
          -ex "attach $pid" -ex "gcore $t" -ex detach -ex quit

        i=0
        for str in hbt= key= dhost= sp= sk= dip=; do
                /usr/bin/strings $t | /bin/grep "${str}[[:digit:]]"
                if [ $? -eq 0 ]; then
                        i=$(($i + 1))
                fi
        done
        /bin/rm $t
        if [ $i -eq 6 ]; then
                echo "CRITICAL: Fokirtor strings found in sshd process ${pid}!"
                exit 2
        fi
done


echo "OK: No indication of Fokirtor found."
exit 0
