#!/bin/sh

# Nagios plugin to monitor conntracking usage (in %) on Linux

# Copyright (c) 2012,2014,2015 Simon Deziel <simon.deziel@gmail.com>

# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.

# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


# Example configuration
#
# This check needs to be installed on the monitoring target and executed through
# NRPE. NRPE config extract example:
#
# command[check_conntrack]=/usr/lib/nagios/plugins/check_conntrack -w 80 -c 90
#
# And the config extract to add to Nagios' config:
#
# define service {
#   use                 'generic-service'
#   service_description 'Conntrack state usage'
#   check_command       'check_nrpe!check_conntrack'
# }
#
# This plugin is useful to track iptables state usage (i.e. to identify a DDoS).

# Explicitly set the PATH to that of ENV_SUPATH in /etc/login.defs and unset
# various other variables. For details, see:
# https://wiki.ubuntu.com/SecurityTeam/AppArmorPolicyReview#Execute_rules
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export ENV=
export CDPATH=

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
MSG_OK="CONNTRACK OK"
MSG_WARNING="CONNTRACK WARNING"
MSG_CRITICAL="CONNTRACK CRITICAL"
MSG_UNKNOWN="CONNTRACK UNKNOWN"
SCRIPT_NAME=$(basename $0)
perf_data="|"
CONNTRACK_BIN="$(/usr/bin/which conntrack 2> /dev/null)"

p_ok () {
  echo "$MSG_OK: $1$perf_data"
  exit "$STATE_OK"
}
p_warning () {
  echo "$MSG_WARNING: $1$perf_data"
  exit "$STATE_WARNING"
}
p_critical () {
  echo "$MSG_CRITICAL: $1$perf_data"
  exit "$STATE_CRITICAL"
}
p_unknown () {
  echo "$MSG_UNKNOWN: $1$perf_data"
  exit "$STATE_UNKNOWN"
}

usage () {
  cat << EOF
Usage:
  $SCRIPT_NAME -w <% of conntrack state used> -c <% of conntrack state used> | -h
EOF
}

long_usage () {
  cat << EOF
Copyright (c) 2012 Simon Deziel

This plugin checks the conntracking usage (in %) on Linux

EOF
  usage
  cat << EOF

This plugin checks when conntracking usage is higher than
the warning/critical thresholds.
EOF
  exit 0
}

# Check arguments
if [ "$#" -eq 0 ]; then
  long_usage
fi

# process command line args
while [ ! -z "$1" ]; do
  case $1 in
    -w|--warning)  shift; WARNING="$1";;
    -c|--critical) shift; CRITICAL="$1";;
    -h|--help)     long_usage;;
  esac
  shift
done

# Check args
[ "$WARNING" -gt 0 ] || p_unknown "Invalid warning threshold, use a value > 0"
[ "$WARNING" -le 100 ] || p_unknown "Invalid warning threshold, use a value <= 100"
[ "$CRITICAL" -gt 0 ] || p_unknown "Invalid critical threshold, use a value > 0"
[ "$CRITICAL" -le 100 ] || p_unknown "Invalid critical threshold, use a value <= 100"

# Define conntrack path (support older kernels)
[ -d "/proc/sys/net/netfilter/" ] && CONNTRACK_PATH="/proc/sys/net/netfilter/nf_conntrack"
[ -d "/proc/sys/net/ipv4/netfilter/" ] && CONNTRACK_PATH="/proc/sys/net/ipv4/netfilter/ip_conntrack"

# Get conntrack count
if [ -x "$CONNTRACK_BIN" ]; then
  # do not count UNREPLIED connections as they are temporary entries so as
  # soon as nf_conntrack_max is reached, UNREPLIED entries are deleted
  # http://www.netfilter.org/documentation/FAQ/netfilter-faq-3.html#ss3.17
  CONNTRACK_COUNT="$($CONNTRACK_BIN -L 2>/dev/null | grep -vwFc '[UNREPLIED]')"
else
  [ -r "${CONNTRACK_PATH}_count" ] || p_unknown "Unable to read the conntrack count"
  CONNTRACK_COUNT="$(cat ${CONNTRACK_PATH}_count)"
fi
[ -z "$CONNTRACK_COUNT" ] && p_unknown "Unable to read the conntrack count"

# Get conntrack max
[ -r "${CONNTRACK_PATH}_max" ] || p_unknown "Unable to read the conntrack max"
CONNTRACK_MAX="$(cat ${CONNTRACK_PATH}_max)"
[ -z "$CONNTRACK_MAX" ] && p_unknown "Unable to read the conntrack max"

USAGE_PERCENT="$(( 100 * $CONNTRACK_COUNT / $CONNTRACK_MAX))"
WARNING_THRESHOLD="$(( $CONNTRACK_MAX * $WARNING / 100))"
CRITICAL_THRESHOLD="$(( $CONNTRACK_MAX * $CRITICAL / 100))"
perf_data="|count=$CONNTRACK_COUNT;$WARNING_THRESHOLD;$CRITICAL_THRESHOLD;0;$CONNTRACK_MAX"

# Compare count against thresholds
if [ "$CONNTRACK_COUNT" -gt "$CRITICAL_THRESHOLD" ]; then
  p_critical "$USAGE_PERCENT% state used ($CONNTRACK_COUNT/$CONNTRACK_MAX) (c=$CRITICAL%, $CRITICAL_THRESHOLD/$CONNTRACK_MAX)"
elif [ "$CONNTRACK_COUNT" -gt "$WARNING_THRESHOLD" ]; then
  p_warning "$USAGE_PERCENT% state used ($CONNTRACK_COUNT/$CONNTRACK_MAX) (w=$WARNING%, $WARNING_THRESHOLD/$CONNTRACK_MAX)"
fi

p_ok "$USAGE_PERCENT% state used ($CONNTRACK_COUNT/$CONNTRACK_MAX)"
