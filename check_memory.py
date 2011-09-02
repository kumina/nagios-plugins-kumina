#!/usr/bin/env python

"""

    Nagios plugin to report Memory usage by parsing /proc/meminfo
    
    by L.S. Keijser <keijser@stone-it.com>
    0.2: Updated by Rutger Spiertz <rutger@kumina.nl>: Add buffers to free mem

    This script takes Cached memory into consideration by adding that
    to the total MemFree value.

"""

from optparse import OptionParser
import sys

checkmemver = '0.2'

# Parse commandline options:
parser = OptionParser(usage="%prog -w <warning threshold> -c <critical threshold> [ -h ]",version="%prog " + checkmemver)
parser.add_option("-w", "--warning",
    action="store", type="string", dest="warn_threshold", help="Warning threshold in percentage")
parser.add_option("-c", "--critical",
    action="store", type="string", dest="crit_threshold", help="Critical threshold in percentage")
(options, args) = parser.parse_args()


def readLines(filename):
    f = open(filename, "r")
    lines = f.readlines()
    return lines

def readMemValues():
    global memTotal, memCached, memBuffers, memFree
    for line in readLines('/proc/meminfo'):
        if line.split()[0] == 'MemTotal:':
            memTotal = line.split()[1]
        if line.split()[0] == 'MemFree:':
            memFree = line.split()[1]
        if line.split()[0] == 'Buffers:':
            memBuffers = line.split()[1]
        if line.split()[0] == 'Cached:':
            memCached = line.split()[1]

def percMem():
    readMemValues()
    return (((int(memFree) + int(memBuffers) + int(memCached)) * 100) / int(memTotal))

def realMem():
    readMemValues()
    return (int(memFree) + int(memBuffers) + int(memCached)) / 1024

def go():
    if not options.crit_threshold:
        print "UNKNOWN: Missing critical threshold value."
        sys.exit(3)
    if not options.warn_threshold:
        print "UNKNOWN: Missing warning threshold value."
        sys.exit(3)
    if int(options.crit_threshold) >= int(options.warn_threshold):
        print "UNKNOWN: Critical percentage can't be equal to or bigger than warning percentage."
        sys.exit(3)
    trueFree = percMem()
    trueMemFree = realMem()
    if int(trueFree) <= int(options.crit_threshold):
        print "CRITICAL: Free memory percentage is less than or equal to " + options.crit_threshold + "%: " + str(trueFree) + "% (" + str(trueMemFree) + " MiB)"
        sys.exit(2)
    if int(trueFree) <= int(options.warn_threshold):
        print "WARNING: Free memory percentage is less than or equal to " + options.warn_threshold + "%: " + str(trueFree) + "% (" + str(trueMemFree) + " MiB)"
        sys.exit(1)
    else:
        print "OK: Free memory percentage is " + str(trueFree) + "% (" + str(trueMemFree) +" MiB)"
        sys.exit(0)

if __name__ == '__main__':
    go()


