#!/bin/sh

if test "$#" -ne 1
then
	echo "CRITICAL - usage: $0 filename"
	exit 2
fi

icinga2 daemon -C -c $1 | exec awk "
BEGIN {
	errors = -1
}
/Finished validating/ {
    errors = 0
}
/^critical\/config: / {
	errors = \$2
}

END {
	if (errors == -1) {
		printf \"Failed to process configuration files\\n\";
		exit 2
	}

	if (errors > 0) {
		printf \"Errors: %d\n\",
			errors;
		exit 2
	} else {
		printf \"Errors: %d\n\",
			errors;
		exit 0
	}
}
"
