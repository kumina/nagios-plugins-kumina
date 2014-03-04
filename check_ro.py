#!/usr/bin/env python
from sys import exit

with open('/proc/mounts', 'r') as f:
    mounts = f.readlines()

ro_mounts = []

for mount in mounts:
    mount = mount.split(' ')
    for opt in mount[3].split(','):
        if opt == 'ro':
            ro_mounts.append(mount[1])

msg = 'Read-Only mounts'
if ro_mounts:
    print '%s CRITICAL: mounted ro: %s' % (msg, ', '.join(ro_mounts))
    exit(1)

print '%s OK: no filesystems mounted ro' % (msg)
