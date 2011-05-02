#!/bin/sh

# Exit codes for crm_verify:
#  0 - Config is ok
#  1 - Config had Errors
#  2 - Parse errors in XML
#  3 - Could not connect to Live CIB

check_ok() {
	MSG="${MSG} OK:"
	NUM_WARN=`echo $OUTPUT | fgrep -c "WARN"`
	NUM_ERROR=`echo $OUTPUT | fgrep -c "ERROR"`
	if [ $NUM_WARN -ne 0 ]; then
		MSG="${MSG} running configuration warnings: ${NUM_WARN}"
	fi
	if [ $NUM_ERROR -ne 0 ]; then
		MSG="${MSG} running configuration errors(non-fatal): ${NUM_ERROR}"
	fi
	if [ $NUM_WARNING -eq 0 -a $NUM_ERROR -eq 0 ]; then
		MSG="${MSG} no warnings or errors"
	fi
	echo "${MSG}"
	exit 0
}

check_not_ok() {
	MSG="${MSG} CRITICAL:"
	if [ $OUTPUT = "sudo: /usr/sbin/crm_verify: command not found" ]; then
            MSG="${MSG} pacemaker is not installed"
        fi
        NUM_ERROR=`echo $OUTPUT | fgrep -c "ERR"`
	NUM_WARN=`echo "$OUTPUT" | fgrep -c "WARN"`
	if [ $NUM_ERROR -ne 0 ]; then
		MSG="${MSG} running configuration errors: ${NUM_ERROR}"
	fi
	if [ $NUM_WARN -ne 0 ]; then
		MSG="${MSG} running configuration warnings: ${NUM_WARN}"
	fi
	echo "${MSG}"
	exit 1
}

check_unknown() {
	MSG="${MSG} WARNING: Unknown status of config"
	echo "${MSG}"
	exit 2
}

check_could_not_complete() {
	MSG="${MSG} CRITICAL: could not connect to live CIB"
	echo "${MSG}"
	exit 1
}

MSG="PACEMAKER"

IFS=
OUTPUT="`sudo /usr/sbin/crm_verify -L -V 2>&1`"

case $? in
0)
	check_ok
	;;
1)
	check_not_ok
	;;
3)
	check_could_not_complete
	;;
*)
	check_unknown
	;;
esac
