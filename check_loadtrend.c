#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void
usage(void)
{
	fprintf(stderr,
"usage: check_loadtrend [-m minimum per-cpu load cutoff]\n"
"                       [-c critical ratio] [-w warning ratio]\n");
	exit(1);
}

static double
getdouble(const char *str)
{
	double number;
	char *ep;

	errno = 0;
	number = strtod(str, &ep);
	if (errno != 0 || *str == '\0' || *ep != '\0') {
		fprintf(stderr, "%s: invalid number\n", str);
		exit(1);
	}
	return (number);
}

static void
testratio(double load1, double load2, double ratio,
    const char *severity, int code, int loadtime1, int loadtime2)
{

	if (load1 >= ratio * load2) {
		printf(
		    "%s - load%d / load%d = %.2lf / %.2lf = %.2lf, "
		    "which is greater than or equal to  %.2lf\n",
		    severity, loadtime1, loadtime2, load1, load2,
		    load1 / load2, ratio);
		exit(code);
	}
}

int
main(int argc, char *argv[])
{
	int ch;
	double minload = 1.5, critratio = 1.5, warnratio = 1.1;
	double ladv[3];
	long ncpus;

	while ((ch = getopt(argc, argv, "c:m:w:")) != -1) {
		switch (ch) {
		case 'c':
			critratio = getdouble(optarg);
			break;
		case 'm':
			minload = getdouble(optarg);
			break;
		case 'w':
			warnratio = getdouble(optarg);
			break;
		default:
			usage();
		}
	}
	argv += optind;
	argc -= optind;
	if (argc != 0)
		usage();

	if (getloadavg(ladv, 3) == -1) {
		printf("CRITICAL - Failed to obtain load averages: %s",
		    strerror(errno));
		return (2);
	}

	ncpus = sysconf(_SC_NPROCESSORS_ONLN);
	if (ncpus == -1) {
		printf(
"CRITICAL - Failed to obtain the number of online CPUs: %s",
		    strerror(errno));
		return (2);
	}

	if (ladv[0] < minload * ncpus) {
		printf("OK - load1 = %.2lf, which is less than %.2lf\n",
		    ladv[0], minload * ncpus);
		return (0);
	}

	testratio(ladv[0], ladv[1], critratio, "CRITICAL", 2, 1, 5);
	testratio(ladv[1], ladv[2], critratio, "CRITICAL", 2, 5, 15);
	testratio(ladv[0], ladv[1], warnratio, "WARNING", 1, 1, 5);
	testratio(ladv[1], ladv[2], warnratio, "WARNING", 1, 5, 15);

	printf("OK - load1 / load5 = %.2lf / %.2lf = %.2lf,"
	           " load5 / load15 = %.2lf / %.2lf = %.2lf\n",
	    ladv[0], ladv[1], ladv[0] / ladv[1],
	    ladv[1], ladv[2], ladv[1] / ladv[2]);
	return (0);
}
