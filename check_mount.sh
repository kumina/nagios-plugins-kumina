#!/bin/sh
# check a mountpoint by looking up /proc/mounts and stat(2)ing the directory

if [ -n "$1" ]; then
  # strip last "/" if exists
  MP="${1%/}"
  MP_regex=$(echo ^${MP}$ | sed 's!/!\\/!g')
else
  echo Usage: $0 mountpoint >&2
  exit 3
fi

# if a mountpoint occurs only once in /proc/mounts returns the exit code of ls(1)
if awk '$2 ~ /'${MP_regex}'/ {print $2}' < /proc/mounts | sort | uniq -c | awk '{print $1}' | grep -q 1
then
  # returns 0 on success, 1 on 'soft' error (won't happen), 2 on error
  if ls -d $MP >/dev/null 2>&1; then
    echo OK: ${MP} mounted and accessible
    exit 0
  else
    echo CRITICAL: ${MP} mounted but not accessible
    exit 2
  fi
else
  # if the mountpoint doesn't occur or occurs more than once
  echo CRITICAL: ${MP} not mounted
  exit 2
fi
