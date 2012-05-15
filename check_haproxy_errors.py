#!/usr/bin/env python
"""
This script tests if a Haproxy backend gave more errors than a specified threshold. This script is meant to be invoked by nagios/icinga.

REQUIREMENTS
This script requires python-argparse and is meant to be run on *nix-systems.

COPYRIGHT
Copyright 2012 - Kumina B.V./Rutger Spiertz (rutger@kumina.nl), this script is licensed under the GNU GPL version 3 or higher.

"""
#Import the classes needed
import argparse
from sys import exit
import socket
import cPickle
import datetime

# Define and initialize global variables
exit_ok = 0
exit_warn = 1
exit_crit = 2
exit_err = 3
msg = ""
datafile = '/var/cache/icinga_haproxy_data'

parser = argparse.ArgumentParser(description="This script tests if a Haproxy backend gave more errors than a specified threshold. This script is meant to be invoked by nagios/icinga.")
parser.add_argument("-i", "--interval", action="store", type=int, default=300, help="The time interval in seconds during which the errors occur (default = %(default)s)")
parser.add_argument("-s", "--socket", action="store", default='/var/run/haproxy.sock', help="The Haproxy socket (default = %(default)s).")
parser.add_argument("-w", "--warning", dest="warn_amount", action="store", type=int, default=10, help="The amount of errors that is acceptable before raising a warning (default = %(default)s)")
parser.add_argument("-c", "--critical",dest="crit_amount", action="store", type=int, default=20, help="The amount of errors that is acceptable before it's critical (default = %(default)s)")

def quit(state):
    print msg
    exit(state)

def addToMsg(newString):
    global msg
    if msg != "":
        msg += " %s" % newString
    else:
        msg += "%s" % newString

class Hapr_data(object):
    def __init__(self, data):
        self.time = datetime.datetime.now()

        parsed_data = {}
        data = data.split('\n')
        firstrow = True
        for row in data:
            if not row:
                continue
            row = row.split(',')
            if firstrow:
                colnum = 0
                for col in row:
                    if col == '# pxname':
                        colnum_pxname = colnum
                    elif col == 'hrsp_5xx':
                        colnum_hrsp_5xx = colnum
                    colnum += 1
                firstrow = False
            else:
                name = row[colnum_pxname]
                value = row[colnum_hrsp_5xx]
                if value == '':
                    value = 0
                parsed_data[name] = int(value)
        self.data = parsed_data

# Script starts here...
args=parser.parse_args()

# Get the current Haproxy data
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(args.socket)
except:
    addToMsg("UNKNOWN: %s can't be opened." % args.socket)
    quit(exit_err)
try:
    s.send('show stat -1 2 -1\n')
    data = s.recv(4096)
except:
    addToMsg("UNKNOWN: error communicating with socket.")
    quit(exit_err)
s.close()
datapoint_current = Hapr_data(data)

# Read the datafile and unpickle the datapoints
try:
    f = open(datafile, 'rb')
except:
    addToMsg('UNKNOWN: error opening datafile ' + datafile)
    quit(exit_err)
datapoints = []
while True:
    try:
        datapoints.append(cPickle.load(f))
    except EOFError:
        break
f.close()
datapoints.append(datapoint_current)
# Check if there is a datapoint to compare with
interval = datetime.timedelta(seconds = args.interval)
points = datapoints[:]
datapoint_compare = None
for i in range(len(points)):
    delta = datapoint_current.time - interval - points[i].time
    if i + 1 in range(len(points)):
        next_delta = datapoint_current.time - interval - points[i + 1].time
        if next_delta < delta and next_delta > datetime.timedelta():
            datapoints.remove(points[i])
            continue
    if delta > datetime.timedelta():
        datapoint_compare = points[i]
    break

# Write the new list of datapoints to the file
try:
    f = open(datafile, 'wb+')
except:
    addToMsg('UNKNOWN: error opening datafile ' + datafile + '.')
    quit(exit_err)
for datapoint in datapoints:
    cPickle.dump(datapoint, f)
f.close()

# Compare the datapoints (if we have 2)
if datapoint_compare is None:
    addToMsg('UNKNOWN: no usable datapoint found.')
    quit(exit_err)
string = ''
errors = ''
warn = False
crit = False
data_current = datapoint_current.data
time_current = datapoint_current.time
data_compare = datapoint_compare.data
time_compare = datapoint_compare.time
errs_for_warn = args.warn_amount / float(args.interval)
errs_for_crit = args.crit_amount / float(args.interval)
for name in data_current.keys():
    if name not in data_compare.keys():
        continue
    value_delta = data_current[name] - data_compare[name]
    td = time_current - time_compare
    time_delta = (td.microseconds + (td.seconds + td.days * 24 * 3600) * 10**6) / 10**6
    errs_per_sec = value_delta / float(time_delta)
    if errs_per_sec >= errs_for_crit:
        if errors == '':
            errors = name + ': ' + str(round(errs_per_sec, 4))
        else:
            errors = errors + ', ' + name + ': ' + str(round(errs_per_sec, 4))
        crit = True
    elif errs_per_sec >= errs_for_warn:
        if errors == '':
            errors = name + ': ' + str(round(errs_per_sec, 4))
        else:
            errors = errors + ', ' + name + ': ' + str(round(errs_per_sec, 4))
        warn = True
    elif string:
        string = string + ', ' + name + ': ' + str(round(errs_per_sec, 4))
    else:
        string = name + ': ' + str(round(errs_per_sec, 4))

# Return the message
if crit:
    addToMsg('CRITICAL: ' + errors)
    quit(exit_crit)
elif warn:
    addToMsg('WARNING: ' + errors)
    quit(exit_warn)
elif string:
    addToMsg('OK: ' + string)
    quit(exit_ok)
else:
    addToMsg('OK: no data to compare.')
    quit(exit_ok)
