#!/usr/bin/env bash
#
# Check SHA1 SSL certificate for expiry after Jan 1 2015
#
# Usage: check_ssl_cert.sh [-h host] [-p port] [-t timeout]
#   -h, --host            servername
#   -p, --port            Port, eg: 443
#   -i  --ip		  IP address or hostname to connect to
#   -t, --timeout         Command execution timeout, eg: 10s
#   --help                Display this screen
#
# (c) 2014, Benjamin Dos Santos <benjamin.dossantos@gmail.com>
# https://github.com/bdossantos/nagios-plugins
# (c) 2015, Liam Macgillavry, Kumina BV <liam@kumina.nl>
#

while [[ -n "$1" ]]; do
  case $1 in
    -h | --host)
      host=$2
      shift
      ;;
    -p | --port)
      port=$2
      shift
      ;;
    -i | --ip)
      ip=$2
      shift
      ;;
    -t | --timeout)
      timeout=$2
      shift
      ;;
    --help)
      sed -n '2,14p' "$0" | tr -d '#'
      exit 3;
      ;;
    *)
      echo "Unknown argument: $1"
      exec "$0" --help
      exit 3
      ;;
  esac
  shift
done

ip=${ip:=localhost}
host=${host:=localhost}
port=${port:=443}
timeout=${timeout:=30s}
warn=${warn:=15}
crit=${crit:=7}

if timeout "$timeout" \
  openssl s_client -servername "$host" -connect "${ip}:${port}" \
  < /dev/null 2>&1 \
  | openssl x509 -text -in /dev/stdin \
  | grep -q 'sha1WithRSAEncryption'; then
  SHA1CERT=true
else
  echo "OK - not a sha1 cert"
  exit 0 
fi

expire=$(
  timeout "$timeout" \
  openssl s_client -servername "$host" -connect "${ip}:${port}" \
  < /dev/null 2>&1 \
  | openssl x509 -enddate -noout \
  | cut -d '=' -f2
)

parsed_expire=$(date -d "$expire" +%s)
today=$(date +%s)
enddate=$(date -d "Jan 1 01:02:03 2016 GMT" +%s)
#echo $expire; echo $parsed_expire; echo $today; echo $enddate
days_before=$(((enddate - parsed_expire) / (60 * 60 * 25)))

if [[ $parsed_expire -lt $enddate ]]; then
  echo "OK - this SHA1 cert will expire before Jan 1 2016 (${days_before} days before)"
  exit 0
elif [[ $parsed_expire -gt $enddate ]]; then
  days_after=$(((parsed_expire - enddate) / (60 * 60 * 24)))
  echo "WARNING - this sha1 cert will expire ${days_after} days after the Jan 1 2016 cutoff date"
  exit 1
elif [[ $today -gt $enddate ]]; then
  echo "WARNING - This SSL SHA1 check has no purpose after Jan 1 2016. Clean me up"
  exit 1
fi

