#!/usr/bin/python
#
# check_mptsas - A Nagios check for MPT RAID controllers with more than one volume.
#
import pexpect
import re
import sys

EXIT_OK = 0
EXIT_CRIT = 1
EXIT_WARN = 2
EXIT_UNKNOWN = 3

# Set logfile to sys.stdout if you want to see the output of the child program
logfile = None
# The path to the lsiutil binary
#binary = '/usr/sbin/lsiutil'
binary = './lsiutil.x86_64'

def getNumVols():
    child = pexpect.spawn (binary,logfile=logfile)
    # Get to the RAID menu and get the number of configured volumes
    child.expect ('Select a device:  \[[^-]+-[^-]+ or 0 to quit\]')
    child.sendline('1')
    child.expect ('Main menu, select an option:  \[[^-]+-[^-]+ or e/p/w or 0 to quit\]')
    child.sendline('21')
    child.expect ('RAID actions menu, select an option:  \[[^-]+-[^-]+ or e/p/w or 0 to quit\]')
    child.sendline('1')
    child.expect ('(\d+) volumes are active, (\d+) physical disks are active')
    numVols,numPhys = child.match.groups()
    child.kill
    return int(numVols),int(numPhys)

def getVolStatus(volID):
    child = pexpect.spawn (binary,logfile=logfile)
    # Get to the RAID menu to get the volume status
    child.expect('Select a device:  \[[^-]+-[^-]+ or 0 to quit\]')
    child.sendline('1')
    child.expect ('Main menu, select an option:  \[[^-]+-[^-]+ or e/p/w or 0 to quit\]')
    child.sendline('21')
    child.expect ('RAID actions menu, select an option:  \[[^-]+-[^-]+ or e/p/w or 0 to quit\]')
    child.sendline('3')
    child.expect ('Volume:  \[[^-]+-[^-]+ or RETURN to quit\]')
    child.sendline(str(volID))
    child.expect ('Volume %d State:  ([^,]+), ([^\W]+)' % (volID))
    state,enablestate = child.match.groups()
    child.kill
    return [state,enablestate]

# Set some variables we can re-assign when checking the disk states
enabledVols = 0
pre_exit = EXIT_OK
exit_msg = 'OK:'
msg = ''

numVols,numPhys = getNumVols()

for x in range(numVols):
    volState = getVolStatus(x)
    if volState[1] != 'enabled':
        # The volume is not enabled, so we do not care about the state.
        continue
    enabledVols += 1
    msg = msg + ' Volume %d: %s.' % (x,volState[0])
    if volState[0] != 'optimal':
        pre_exit = EXIT_CRIT
        exit_msg = 'CRITICAL:'

print exit_msg + ' %d Volumes configured, %d Volumes enabled. %d Physical Disks used.' % (numVols, enabledVols, numPhys) + msg
sys.exit(pre_exit)
