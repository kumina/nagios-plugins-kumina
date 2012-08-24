#!/bin/sh

# NAGIOS Exit codes
NAGIOS_OK=0
NAGIOS_WARNING=1
NAGIOS_CRITICAL=2
NAGIOS_UNKNOWN=3

PROGNAME=`basename $0 .sh`
VERSION="Version 1.0"

WGET=`which wget`
GREP=`which grep`

print_version() {
    echo "$VERSION"
}

print_help() {
    print_version $PROGNAME $VERSION
    echo ""
    echo "$PROGNAME is a Nagios plugin to check a specific Tomcat Application."
    echo ""
    echo "$PROGNAME -u user -p password -H host -P port -a application"
    echo ""
    echo "Options:"
    echo "  -u/--user)"
    echo "     User name for authentication on Tomcat Manager Application"
    echo "  -p/--password)"
    echo "     Password for authentication on Tomcat Manager Application"
    echo "  -H/--host)"
    echo "     Host Name of the server (default: localhost)"
    echo "  -P/--port)"
    echo "     Port Number Tomcat service is listening on (default: 8080)"
    echo "  -a/--appname)"
    echo "     Application name to be checked"
    exit $NAGIOS_UNKNOWN
}

if [ ! -x "$WGET" ]
then
	echo "wget not found!"
	exit $NAGIOS_CRITICAL
fi

if [ ! -x "$GREP" ]
then
	echo "grep not found!"
	exit $NAGIOS_CRITICAL
fi

if test -z "$1"
then
	print_help
	exit $NAGIOS_CRITICAL
fi

while test -n "$1"; do
    case "$1" in
        --help|-h)
            print_help
            exit $NAGIOS_OK
            ;;
        --version|-v)
            print_version $PROGNAME $VERSION
            exit $NAGIOS_OK
            ;;
        --user|-u)
            USER=$2
            shift
            ;;
        --password|-p)
            PASSWORD=$2
            shift
            ;;
        --host|-H)
            HOST=$2
            shift
            ;;
        --port|-P)
            PORT=$2
            shift
            ;;
        --appname|-a)
            APP=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_help
            exit $NAGIOS_UNKNOWN
            ;;
        esac
    shift
done

if [ -z $PORT ]; then
    PORT=8080
fi

if [ -z $HOST ]; then
    HOST='localhost'
fi

if wget -o /dev/null -O - http://$USER:$PASSWORD@$HOST:$PORT/manager/list | grep -q "^/$APP:running"
then
    echo "OK: Application $APP is running!"
    exit $NAGIOS_OK
else
    echo "CRITICAL: Application $APP is not running!"
    exit $NAGIOS_CRITICAL
fi
