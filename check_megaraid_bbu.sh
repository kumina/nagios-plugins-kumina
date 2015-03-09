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
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Voltage" | grep -v "Voltage:" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    status_temprature)
      # Check temperature status
      # Result: OK/??
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Temperature" | grep -v "Temperature:" | grep -v "Over Temperature" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    relearn_cycle_requested)
      # Check if learn cycle has been requested
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Learn Cycle Requested" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    relearn_cycle_active)
      # Check if learn cycle is active.
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Learn Cycle Active" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    relearn_cycle_status)
      # Check learn cycle status
      # Result: OK/??
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Learn Cycle Status" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    relearn_cycle_timeout)
      # Check learn cycle timeout
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Learn Cycle Timeout" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    i2c_errors_detected)
      # Check for i2c errors
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "I2c Errors Detected" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    battery_pack_missing)
      # Check if battery pack is missing
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Battery Pack Missing" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    battery_replacement_required)
      # Check if battery replacement is required
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Battery Replacement required" | cut -d ":" -f2 | sed -e 's/^[[:space:]]*//'
    ;;
    remaining_capacity_low)
      # Check remaining capacity
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Remaining Capacity Low" | cut -d":" -f2 |  tr -d '[[:space:]]'
    ;;
    periodic_learn_required)
      # Check  unkown
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Periodic Learn Required" | cut -d":" -f2 |  tr -d '[[:space:]]'
    ;;
    transparent_learn)
      # Check unknow
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Transparent Learn" | cut -d":" -f2 |  tr -d '[[:space:]]'
    ;;
    no_space_cache_offload)
      # Check unknow
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "No space to cache offload" | cut -d":" -f2 |  tr -d '[[:space:]]'
    ;;
    cache_offload_premium_required)
      # Check unknow
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Cache Offload premium feature required" | cut -d":" -f2 |  tr -d '[[:space:]]'
    ;;
    module_microcode_update_required)
      # Check unknow
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "No space to cache offload" | cut -d":" -f2 |  tr -d '[[:space:]]'
    ;;
    battery_replacement_adviced)
      # Check preventive failure status
      # Result: Yes/No
      $MEGACLI -AdpBbuCmd -GetBbuStatus -a$ADAPTER | grep "Pack is about to fail & should be replaced" | cut -d":" -f2 |  tr -d '[[:space:]]'
    ;;
    *)
      echo "Usage: $0 [check name]" 
      exit 1
  esac
