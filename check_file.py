#!/usr/bin/env python
"""
This script tests if the first line of a specified file contains a specified
content. This script is meant to be invoked by nagios/icinga.

REQUIREMENTS
This script requires python-argparse and is meant to be run on *nix-systems.

COPYRIGHT
Copyright 2011-2016 - Kumina B.V./Rutger Spiertz (rutger@kumina.nl), this script
is licensed under the GNU GPL version 3 or higher.
"""

# Import the classes needed
import argparse
from sys import exit
from os import path

# Define and initialize global variables
exit_ok = 0
exit_warn = 1
exit_crit = 2
exit_err = 3
msg = ''

parser = argparse.ArgumentParser(
    description=('This script tests if the first line of a specified file'
                 ' contains a specified content. This script is meant to be'
                 ' invoked by nagios/icinga.'))
parser.add_argument(
    '-f', '--filename', action='store', required=True,
    help='The file (with path) to check.')
parser.add_argument(
    '-c', '--content', action='store',
    help='The content that is expected to be on the first line of the file.')
parser.add_argument(
    '-n', '--negate', action='store_true',
    help=('Specifies that the file should not exist, the first line is'
          ' returned if it does exist.'))
parser.add_argument(
    '-w', '--warn', action='store_true',
    help='Warn instead of crit when the files existence or content is wrong.')


def quit(state):
    global msg
    if state == exit_warn:
        msg = 'WARNING: ' + msg
    elif state == exit_crit:
        msg = 'CRITICAL: ' + msg
    else:
        msg = 'OK: ' + msg
    print msg
    exit(state)


def addToMsg(newString):
    global msg
    if msg != '':
        msg += ' %s' % newString
    else:
        msg += '%s' % newString

# Script starts here...
args = parser.parse_args()

if args.warn:
    exit_crit = exit_warn

# Get the file content
if path.isfile(args.filename):
    try:
        f = open(args.filename, 'r')
    except:
        addToMsg("%s can't be read." % args.filename)
        quit(exit_crit)
else:
    if args.negate:
        addToMsg("%s doesn't exist." % args.filename)
        quit(exit_ok)
    else:
        addToMsg("%s doesn't exist." % args.filename)
        quit(exit_crit)

fileContent = ''
if args.content != None:
    fileContent = f.readline().strip()
    f.close

if args.negate:
    addToMsg('%s' % fileContent or '%s exists' % args.filename)
    quit(exit_crit)
elif args.content != None and fileContent != args.content:
    addToMsg('the content of %s doesn\'t equal "%s".' % (args.filename,
                                                         args.content))
    quit(exit_crit)
else:
    addToMsg('File is on disk with content as expected (if checked).')
    quit(exit_ok)
