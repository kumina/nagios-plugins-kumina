#!/bin/bash
#
# check_megaraid_bbu - Script to check status of LSI battery.
#
# Copyright 2015 - Kumina B.V.
# Licensed under the terms of the GNU GPL version 3 or higher

  abort() { echo -e "\nERROR: $1" >&2; exit 1; }

## Variables

  LOGGER=$(which logger) || abort 'logger not found in the path.'
  MEGACLI=$(which megacli) || abort 'megacli not found in the path.'
  ADAPTER=ALL     # On which adapter the check should be executed.

## General

  # Check we are run as root
  if [ "$(whoami)" != "root" ] ; then
    abort 'Please run this script as root.'
  fi

##  BBU Firmware status

  case $1 in
    status_voltage)

      # Check voltage status
      # Result: OK/??

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Voltage" | grep -v "Voltage:" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'OK' ]
      then
        echo "Voltage is OK"
        exit 0 
      else
        echo "Voltage is NOT OK"
        exit 2
      fi

    ;;
    status_temprature)

      # Check temperature status
      # Result: OK/??

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Temperature" | grep -v "Temperature:" | grep -v "Over Temperature" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'OK' ]
      then
        echo "Temperature is OK"
        exit 0
      else
        echo "Temperature is NOT OK"
        exit 2
      fi

    ;;
    relearn_cycle_requested)

      # Check if learn cycle has been requested
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Learn Cycle Requested" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'No' ]
      then
        echo "No relearn cycle requested"
        exit 0
      else
        echo "Relearn cycle requested"
        exit 1
      fi

    ;;
    relearn_cycle_active)

      # Check if learn cycle is active.
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Learn Cycle Active" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'No' ]
      then
        echo "No relearn cycle active"
        exit 0
      else
        echo "Relearn cycle active"
        exit 1
      fi

    ;;
    relearn_cycle_status)

      # Check learn cycle status
      # Result: OK/??

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Learn Cycle Status" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'OK' ]
      then
        echo "Relearn status is OK"
        exit 0
      else
        echo "Relearn status is NOT OK"
        exit 2
      fi

    ;;
    relearn_cycle_timeout)

      # Check learn cycle timeout
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Learn Cycle Timeout" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'No' ]
      then
        echo "No relearn cycle timeout"
        exit 0
      else
        echo "Relearn has timed out"
        exit 1
      fi

    ;;
    i2c_errors_detected)

      # Check for i2c errors
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "I2c Errors Detected" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'No' ]
      then
        echo "No i2c errors"
        exit 0
      else
        echo "An i2c error has occurred"
        exit 1
      fi

    ;;
    battery_pack_missing)

      # Check if battery pack is missing
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Battery Pack Missing" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'No' ]
      then
        echo "Battery pack is present"
        exit 0
      else
        echo "Battery pack is missing"
        exit 2
      fi

    ;;
    battery_replacement_required)

      # Check if battery replacement is required
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Battery Replacement required" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//')
      if [ $RESULT = 'No' ]
      then
        echo "Battery pack does not need replacement"
        exit 0
      else
        echo "Battery pack needs replacement"
        exit 2
      fi

    ;;
    battery_replacement_advised)

      # Check preventive failure status
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Pack is about to fail & should be replaced" | cut -d":" -f2 |  tr -d '[[:space:]]')
      if [ $RESULT = 'No' ]
      then
        echo "Preventive battery replacement is not advised"
        exit 0
      else
        echo "Preventive battery replacement is advised"
        exit 1
      fi

    ;;
    remaining_capacity_low)

      # Check remaining capacity
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Remaining Capacity Low" | cut -d":" -f2 |  tr -d '[[:space:]]')
      if [ $RESULT = 'No' ]
      then
        echo "Remaining capacity is OK"
        exit 0
      else
        echo "Remaining capacity low"
        exit 1
      fi

    ;;
    periodic_learn_required)

      # Check unkown
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Periodic Learn Required" | cut -d":" -f2 |  tr -d '[[:space:]]')
      if [ $RESULT = 'No' ]
      then
        echo "Periodic learn not required"
        exit 0
      else
        echo "Periodic learn required"
        exit 1
      fi

    ;;
    transparent_learn)

      # Check unknow
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Transparent Learn" | cut -d":" -f2 |  tr -d '[[:space:]]')
      if [ $RESULT = 'No' ]
      then
        echo "Transparent learn is disabled"
        exit 0
      else
        echo "Transparent learn is enabled"
        exit 1
      fi

    ;;
    no_space_cache_offload)

      # Check unknow
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "No space to cache offload" | cut -d":" -f2 |  tr -d '[[:space:]]')
      if [ $RESULT = 'No' ]
      then
        echo "Enough space to cache offload"
        exit 0
      else
        echo "No space to cache offload"
        exit 1
      fi

    ;;
    cache_offload_premium_required)

      # Check unknow
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Cache Offload premium feature required" | cut -d":" -f2 |  tr -d '[[:space:]]')
      if [ $RESULT = 'No' ]
      then
        echo "Cache Offload premium feature not required"
        exit 0
      else
        echo "Cache Offload premium feature required"
        exit 1
      fi

    ;;
    module_microcode_update_required)

      # Check unknow
      # Result: Yes/No

      RESULT=$($MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER -NoLog | grep "Module microcode update required" | cut -d":" -f2 |  tr -d '[[:space:]]')
      if [ $RESULT = 'No' ]
      then
        echo "Module microcode update is not required"
        exit 0
      else
        echo "Module microcode update required"
        exit 1
      fi

    ;;
    -h|--help)

      # Show usage
      echo "Usage: $0 [CHECKNAME]" 
      exit 0

    ;;
    *)

      # Show usage
      echo "Usage: $0 [CHECKNAME]" 
      exit 0

  esac
