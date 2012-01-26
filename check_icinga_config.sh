#!/bin/sh

if test "$1" = "-q"
then
	quiet=1
	shift
else
	quiet=0
fi
if test "$#" -ne 0
then
	echo "CRITICAL - usage: $0 [-q], where -q hides warnings"
	exit 2
fi

icinga -v /etc/icinga/icinga.cfg | exec awk "
BEGIN {
	warnings = -1
	errors = -1
}
/^Total Warnings: / {
	warnings = \$3
}
/^Total Errors: / {
	errors = \$3
}

END {
	if (warnings == -1 || errors == -1) {
		printf \"CRITICAL - failed to process configuration files\\n\";
		exit 2
	}

	if (errors > 0) {
		printf \"CRITICAL - warnings: %d, errors: %d\n\",
			warnings, errors;
		exit 2
	} else if (warnings > 0 && $quiet == 0) {
		printf \"WARNING - warnings: %d, errors: %d\n\",
			warnings, errors;
		exit 1
	} else {
		printf \"OK - warnings: %d, errors: %d\n\",
			warnings, errors;
		exit 0
	}
}
"
