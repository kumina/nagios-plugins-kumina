#!/bin/sh

pct_warn=50
pct_crit=75

while getopts w:c: name
do
	case $name in
	w)
		pct_warn="$OPTARG"
		;;
	c)
		pct_crit="$OPTARG"
		;;
	*)
		echo "usage: $0 [-w pct_warn] [-c pct_crit] [args ...]\n" >&2
		exit 1
	esac
done
shift $(($OPTIND - 1))

mysql "$@" << EOF | awk "
BEGIN {
	cur = -1;
	max = -1;
}

/Threads_connected/ {
	cur = \$2;
}
/max_connections/ {
	max = \$2;
}

END {
	if (cur == -1 || max == -1) {
		printf \"CRITICAL - failed to parse MySQL output\\n\";
		exit 2
	}

	pct = 100 * cur / max
	if (pct >= $pct_crit) {
		printf \"CRITICAL - connections: %d/%d (%.2f%%)\\n\",
		    cur, max, pct;
		exit 2
	} else if (pct >= $pct_warn) {
		printf \"WARNING - connections: %d/%d (%.2f%%)\\n\",
		    cur, max, pct;
		exit 1
	} else {
		printf \"OK - connections: %d/%d (%.2f%%)\\n\",
		    cur, max, pct;
		exit 0
	}
}
"
SHOW GLOBAL STATUS WHERE variable_name = 'Threads_connected';
SHOW GLOBAL VARIABLES WHERE variable_name = 'max_connections';
EOF
