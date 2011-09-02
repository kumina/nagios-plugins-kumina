#!/usr/bin/env python
"""
This script checks the "zone" on two nameservers("master" and "slave") by querying both namerservers for the SOA record of that zone.
It then extracts the serialnumber from the record and compares them, it they match a timestamp is written to a temporary file.
If they do not match the script compares the current time with the timestamp, if the nameservers are out of sync for too long it exits with a message indicating this.

This script is meant for nagios/icinga checks, who doesn't want to know if their nameservers are in sync? It supports the options -w and -c to specify the timeout. 

RATIONALE
When you use a PowerDNS master server with BIND slaves and use an older version of PowerAdmin to administer your zones you can get in trouble, 2 bugs are the cause for the need of this script:
	1. PowerAdmin does not do validation of input(e.g. a CNAME and A record for the same hostname is accepted and inserted into PowerDNS).
	2. When there is a CNAME and A record for the same hostname, BIND stops serving the entire zone that hostname is in. (see where I'm going here)

This, along with the need to check if the master and slaves are in sync(or not out of sync for too long during an {I,A}XFR), gave birth to the idea of a nagios check.

REQUIREMENTS
This script requires python-ipaddr, python-argparse and python-dnspython and is meant to be run on *nix-systems.

COPYRIGHT
Copyright 2011 - Kumina B.V./Pieter Lexis (pieter@kumina.nl), this script is licensed under the GNU GPL version 3 or higher.

"""
#Import the classes needed
#TODO: remove time and only use datetime
import dns.resolver
import dns.message
import dns.rrset
import argparse
import ipaddr
from sys import exit
from os import getuid
import time
import datetime

# Define and initialize global variables
exit_ok = 0
exit_warn = 1
exit_crit = 2
exit_err = 3
msg = ""

parser = argparse.ArgumentParser(description="This script tests if and for how long the master and slave nameservers are out of sync, it retains it's state by creating a timestamped file. This script is meant to be invoked by nagios/icinga.")
parser.add_argument("-w", "--warning", metavar="MINUTES", dest="warningTime", action="store", type=int, default=10, help="The amount of time in minutes the slave can be out of sync with the master without raising a warning(default = 10)")
parser.add_argument("-c", "--critical", metavar="MINUTES", dest="criticalTime", action="store", type=int, default=15, help="The amount of time in minutes the slave can be out of sync with the master before it's critical(default = 15)")
parser.add_argument("-v", "--verbose", action="store_true",  default=False, dest="verbose")
parser.add_argument("-s", "--slave", action="store", default="localhost", dest="slave", help="The slave nameserver hostname or IP-address")
parser.add_argument("zone", action="store", help="The zone to be checked")
parser.add_argument("master", action="store", help="The master nameserver hostname or IP-address")

def quit(state):
	print msg
	exit(state)
	
def isIP(nameserver):
	try:
		ipaddr.IPAddress(nameserver)
		return True
	except: #it is not an IP address
		return False

def getIP(nameserver): # we need the IP of the nameserver to query
	if not isIP(nameserver): 
		try:
			return dns.resolver.query(nameserver)[0].address
		except:
			addToMsg("UNKNOWN: Cannot get nameserver ip: %s" % nameserver)
			quit(exit_err)
	else: # It is already an ip
		return nameserver

def getSerial(nameserver):
	nameserver = getIP(nameserver) 
	# dnspython cannot do something like this:
	# $ dig kumina.nl @ns.kumina.nl SOA
	# it requires the ip address of the nameserver to query
	try:
		return dns.query.udp(dns.message.make_query(args.zone, dns.rdatatype.from_text("SOA")), nameserver, timeout=4).answer[0].to_text().split(" ")[6]
		# Create a dns.query.Query object and do the query over udp to nameserver
		# Then, take the first(SOA only returns 1 answer) answer dns.rrset.RRset, make a string from it and that(is in the format of "zone TTL IN SOA ns.zone hostmaster.zone serial")
		# Split the string and take the 7th word, which is the serial(as per RFC 1034 and 1035)
	except:
		addToMsg ("UNKNOWN: Cannot get SOA data from nameserver %s." %  nameserver)
		quit(exit_err)

def compareTime(oldTime):
	timeDifference = abs((datetime.datetime.today() - oldTime)).seconds # The total difference in seconds

	if timeDifference >= datetime.timedelta(minutes=args.criticalTime).seconds: # The timestamp in the file is from more than criticalTime minutes ago
		addToMsg("CRITICAL: " + showTimeDifference(timeDifference))
		if args.verbose:
			addToMsg(showSerials())
		quit(exit_crit)
	elif timeDifference >= datetime.timedelta(minutes=args.warningTime).seconds: # The timestamp in the file is from more than warningTime minutes ago
		addToMsg("WARNING: " + showTimeDifference(timeDifference))
		if args.verbose:
			addToMsg(showSerials())
		quit(exit_warn)
	else: # warningTime nor errorTime minutes have expired 
		addToMsg("OK: " + showTimeDifference(timeDifference))
		if args.verbose:
			addToMsg(showSerials())
		quit(exit_ok)

def showSerials():
	return "Serial for %s is %s, for %s it's %s." % (args.master, masterSerial, args.slave, slaveSerial)

def showTimeDifference(numSeconds):
	return "Serials don't match for %s." % datetime.timedelta(seconds=numSeconds)

def writeTimeToFile(filename):
	try:
		f = open(filename, "w")
		f.write("%d" % time.time())
		f.close
	except:
		addToMsg("Error while making statefile %s" % (filename))

def addToMsg(newString):
	global msg
	if msg != "":
		msg += " %s" % newString
	else:
		msg += "%s" % newString

# Script starts here.....
args=parser.parse_args()
addToMsg("DNS-ZONE %s" % args.zone)

# Get the serials
masterSerial = getSerial(args.master)
slaveSerial = getSerial(args.slave)
filename = "/tmp/dns_check_%s_%s" % (args.zone, getuid())

if masterSerial == slaveSerial: # True: everything is peachy
	addToMsg("OK: serial is %s." % masterSerial)
	writeTimeToFile(filename)
	quit(exit_ok)
else: # Oh oh, master and slave are out of sync
	oldTime = None
	try: # Get the previous timestamp
		f = open(filename, "r")
		oldTime = f.readline()
		f.close
		oldTime = datetime.datetime.fromtimestamp(int(oldTime))
	except:
		addToMsg("UNKNOWN: Serials do not match.")
		if args.verbose:
			addToMsg(showSerials())
		addToMsg("Additionally, cannot get old timestamp from %s" % filename + ".")
		writeTimeToFile(filename)# Try to write the statefile
		quit(exit_err) # Exit regardless
	
	compareTime(oldTime)
