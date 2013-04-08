#!/usr/bin/env python
"""
This simple script checks the DNSSEC validity of a zone.

Copyright 2013 - Kumina B.V./Pieter Lexis (pieter@kumina.nl)
Licensed under the terms of the GNU GPL version 3 or higher
"""
#Import the classes needed
import argparse
import unbound
from sys import exit

# Define and initialize global variables
exit_ok = 0
exit_warn = 1
exit_crit = 2
exit_err = 3
msg = ""

parser = argparse.ArgumentParser(description="This script tests the zone for validation failures by looking up the SOA record. This script is meant to be invoked by nagios/icinga.")
parser.add_argument("-H", action="store", dest='ignore', help="An option to work around a quirk in the kumina Icinga setup, ignored")
parser.add_argument("zone", action="store", metavar='ZONE', help="The zone to be checked")

def quit(state):
    print msg
    exit(state)

def addToMsg(newString):
    global msg
    if msg != "":
        msg += " %s" % newString
    else:
        msg += "%s" % newString

# Script starts here.....
args=parser.parse_args()

ctx = unbound.ub_ctx()

# This key-file should be created once using unbound-anchor(8)
ctx.set_option('auto-trust-anchor-file:', '/var/lib/nagios/root.key')

status, result = ctx.resolve(args.zone, rrtype=unbound.RR_TYPE_SOA)

if status == 0:
    if result.secure:
        addToMsg("OK %s: the chain of trust is valid." % args.zone)
        quit(exit_ok)
    else:
        if result.bogus:
            addToMsg("CRITICAL %s: %s" % (args.zone, result.why_bogus))
            quit(exit_crit)
        else:
            addToMsg("WARNING %s: Result not secure (but not bogus)" % args.zone)
            quit(exit_warn)
else:
    addToMsg("UNKNOWN: resolver failure.")
    quit(exit_err)

# we should never get here
quit(exit_err)
