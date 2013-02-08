#!/usr/bin/env python
"""
"This script warns if snapshots are present and crits if they're almost full. This script is meant to be invoked by nagios/icinga."

REQUIREMENTS
This script requires python-argparse and is meant to be run on *nix-systems.

COPYRIGHT
Copyright 2013 - Kumina B.V./Natasja Kranendonk (natasja@kumina.nl), this script is licensed under the GNU GPL version 3 or higher.

"""
#Import the classes needed
import argparse
from sys import exit
from os import popen

# Define and initialize global variables
exit_ok = 0
exit_warn = 1
exit_crit = 2
exit_err = 3
warn_msg = ""
crit_msg = ""

parser = argparse.ArgumentParser(description="This script warns if snapshots are present and crits if they're almost full. This script is meant to be invoked by nagios/icinga.")
parser.add_argument("-m", "--max_use", action="store", required=True, help="The maximum allowed use percentage.")

def quit(state):
    print msg
    exit(state)

def addToMsg(newString, message):
    if message != "":
        message += " | %s" % newString
    else:
        message += "%s" % newString
    return message

# Script starts here...
args=parser.parse_args()
warn = crit = False
try:
    p = popen("lvs --noheadings")
except:
    msg = 'UNKNOWN: failed to run "lvs --noheadings"'
    quit(exit_err)
while 1:
    line = p.readline()
    if not line:
        break
    something = line.split()
    if len(something) > 4:
        if float(something[5]) >= float(args.max_use):
            crit = True
            crit_msg = addToMsg('name:%s, origin:%s, in use:%s' % (something[0], something[4], something[5]), crit_msg)
        else:
            warn = True
            warn_msg = addToMsg('name:%s, origin:%s, in use:%s' % (something[0], something[4], something[5]), warn_msg)
if crit:
    msg = 'CRITICAL: %s' % crit_msg
    if warn:
        msg += ' | WARNING: %s' % warn_msg
    quit(exit_crit)
elif warn:
    msg = 'WARNING: %s' % warn_msg
    quit(exit_warn)
else:
    msg = 'OK: No snapshots found.'
    quit(exit_ok)
