#!/usr/bin/env python
from os import listdir
from sys import exit
from time import time
import argparse
# Define and initialize global variables
exit_ok = 0
exit_warn = 1
exit_crit = 2
exit_err = 3

parser = argparse.ArgumentParser(description="This script checks for the age of the oldest item in the nullmailer queue")
parser.add_argument("-w", "--warning", metavar="MINUTES", dest="warningTime", action="store", type=int, default=10, help="The age of the file in minutes without raising a warning (default = 10)")
parser.add_argument("-c", "--critical", metavar="MINUTES", dest="criticalTime", action="store", type=int, default=15, help="The age of the file in minutes before it's critical (default = 15)")
parser.add_argument("-f", "--filepath", metavar="PATH/TO/QUEUE", action="store", default="/var/spool/nullmailer/queue", help="The full path to the nullmailer queue directory (default=/var/spool/nullmailer/queue)")

args=parser.parse_args()
try:
	files = listdir(args.filepath)
except:
	print "nullmailer UNKNOWN: Queue does not exist at %s" % args.filepath
	exit(exit_err)

if files  == []:
	# It's empty, move along people
	print "nullmailer OK: no mails in queue"
	exit(exit_ok)
else:
	# Put the oldest file (lowest timestamp) in front of the list
	files.sort()
	# Get the timestamp
	oldest_time = int(files[0].split('.')[0])
	time_now = int(time())
	# is it older than warning minutes?
	if oldest_time + (args.warningTime * 60) < time_now:
		# Is it older than critical minutes?
		if oldest_time + (args.criticalTime * 60) < time_now:
			print "nullmailer CRITICAL: Oldest item in queue older than %s minutes" % args.criticalTime
			exit(exit_crit)
		print "nullmailer WARNING: Oldest item in queue older than %s minutes" % args.warningTime
		exit(exit_warn)
	else:
	# There are items in the queue, but they haven't expired
		print "nullmailer OK: mails in queue, but not too old"
		exit(exit_ok)
