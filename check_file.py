#!/usr/bin/env python
"""
This script tests if the first line of a specified file contains a specified content. This script is meant to be invoked by nagios/icinga.

REQUIREMENTS
This script requires python-argparse and is meant to be run on *nix-systems.

COPYRIGHT
Copyright 2011 - Kumina B.V./Rutger Spiertz (rutger@kumina.nl), this script is licensed under the GNU GPL version 3 or higher.

"""
#Import the classes needed
import argparse
from sys import exit
from os import getuid, path
import time
import datetime

# Define and initialize global variables
exit_ok = 0
exit_warn = 1
exit_crit = 2
exit_err = 3
msg = ""

parser = argparse.ArgumentParser(description="This script tests if the first line of a specified file contains a specified content. This script is meant to be invoked by nagios/icinga.")
parser.add_argument("-f", "--filename", action="store", required=True, help="The file (with path) to check.")
parser.add_argument("-c", "--content", action="store", help="The content that is expected to be on the first line of the file.")
parser.add_argument("-n", "--negate", action="store_true", help="Specifies that the file should not exist, the first line is returned if it does exist.")

def quit(state):
    print msg
    exit(state)

def addToMsg(newString):
    global msg
    if msg != "":
        msg += " %s" % newString
    else:
        msg += "%s" % newString

# Script starts here...
args=parser.parse_args()

# Get the file content
if path.isfile(args.filename):
    try:
        f = open(args.filename, "r")
    except:
        addToMsg("CRITICAL: %s can't be read." % args.filename)
        quit(exit_crit)
else:
    if args.negate:
        addToMsg("OK: %s doesn't exist." % args.filename)
        quit(exit_ok)
    else:
        addToMsg("CRITICAL: %s doesn't exist." % args.filename)
        quit(exit_crit)
fileContent = f.readline().strip()
f.close

if args.negate:
    addToMsg("CRITICAL: %s" % fileContent)
    quit(exit_crit)
elif fileContent == args.content:
    addToMsg("OK: content is \"%s\"." % fileContent)
    quit(exit_ok)
else:
    addToMsg("CRITICAL: the content of %s doesn't equal \"%s\"." % (args.filename, args.content))
    quit(exit_crit)
