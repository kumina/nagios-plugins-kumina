#!/usr/bin/env python
import subprocess
import sys

msg = "DNS ZONES "

try:
    out = subprocess.check_output('/usr/bin/pdnssec check-all-zones'.split()).split('\n')
except:
    print msg + "UNKNOWN: cannot execute /usr/bin/pdnssec"
    sys.exit(3)

bad_zones = ""
details = []
exit_num = 0

for x in out[:-2]:
    splitted = x.split(' ')

    if splitted[0] == 'Checked':
        if int(splitted[5]) > 0 or int(splitted[7]) > 0:
            # Errors, so CRIT
            if int(splitted[5]) > 0:
                exit_num = 2

            # Warnings, so WARN
            if int(splitted[7]) > 0 and exit_num < 1:
                exit_num = 1

            bad_zones += " %s: E:%s, W:%s;" % (splitted[4][1:-2], splitted[5], splitted[7])
        # Go to the next iteration
        continue

    if splitted[0] == '[Warning]' or splitted[0] == '[Error]':
        details.append(x)
        continue

    # If we get here, we couldn't understand the line, throw an UNKNOWN
    print msg + "UNKNOWN: Unable to parse line: %s" % x
    sys.exit(3)

if exit_num == 0:
    print msg + "OK"
if exit_num == 1:
    print msg + "WARNING:" + bad_zones
if exit_num == 2:
    print msg + "CRITICAL:" + bad_zones

print '\n'.join(details)
exit(exit_num)
