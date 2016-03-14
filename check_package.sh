#!/bin/bash
# check whether a package is installed or not

if [ -n "$1" ]; then
  x=($@)
  if [ ! -z ${x[2]} ]; then
    echo "Usage: $0 [not] packagename" >&2
    exit 3
  fi
  if [ "${x[0]}" = "not" ]; then
    NOT=true
    PACKAGE=${x[1]}
  else
    NOT=false
    PACKAGE=${x[0]}
  fi
else
  echo "Usage: $0 [not] packagename" >&2
  exit 3
fi

# if a package is installed, return OK, else return WARNING.
if dpkg -l $PACKAGE >/dev/null 2>&1
then
  if $NOT; then
    echo "WARNING: ${PACKAGE} is installed"
    exit 1
  else
    echo "OK: ${PACKAGE} is installed"
    exit 0
  fi
else
  if $NOT; then
    echo "OK: ${PACKAGE} is not installed"
    exit 0
  else
    echo "WARNING: ${PACKAGE} is not installed"
    exit 1
  fi
fi
