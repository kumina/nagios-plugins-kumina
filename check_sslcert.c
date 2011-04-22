#include <errno.h>
#include <fts.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include <openssl/err.h>
#include <openssl/pem.h>

static time_t tnow, tcritical, twarning;
static unsigned long dayscritical = 7, dayswarning = 30;
static char badfiles[1024] = "";

static void
usage(void)
{

	fprintf(stderr,
"usage: check_sslcert [-c dayscritical] [-w dayswarning] file ...\n");
	exit(1);
}

static void
appendfn(const char *filename, const char *reason)
{
	size_t lf, lb, lr;

	lb = strlen(badfiles);
	lf = strlen(filename);
	lr = strlen(reason);

	if (lb + lf + lr + 5 <= 1024) {
		badfiles[lb] = ' ';
		strcpy(&badfiles[lb + 1], filename);
		strcpy(&badfiles[lb + lf + 1], " (");
		strcpy(&badfiles[lb + lf + 3], reason);
		strcpy(&badfiles[lb + lf + lr + 3], ")");
	}
}

static int
check_sslcert_file(const char *filename)
{
	FILE *f;
	X509 *c;
	ASN1_TIME *nb, *na;
	int badness = 0;
	char msg[40];

	f = fopen(filename, "r");
	if (f == NULL) {
		appendfn(filename, "file not found");
		return (2);
	}

	c = PEM_read_X509(f, NULL, NULL, NULL);
	fclose(f);
	if (c == NULL) {
		appendfn(filename, "not a certificate");
		return (2);
	}

	nb = X509_get_notBefore(c);
	na = X509_get_notAfter(c);
	if (X509_cmp_time(nb, &tnow) > 0) {
		appendfn(filename, "not valid yet");
		badness = 2;
	} else if (X509_cmp_time(na, &tnow) < 0) {
		appendfn(filename, "expired");
		badness = 2;
	} else if (X509_cmp_time(na, &tcritical) < 0) {
		snprintf(msg, sizeof msg, "expires within %lu days",
		    dayscritical);
		appendfn(filename, msg);
		badness = 2;
	} else if (X509_cmp_time(na, &twarning) < 0) {
		snprintf(msg, sizeof msg, "expires within %lu days",
		    dayswarning);
		appendfn(filename, msg);
		badness = 1;
	}
	X509_free(c);
	return (badness);
}

static int
check_sslcert(char **paths)
{
	FTS *f;
	FTSENT *fe;
	size_t pos;
	int ret = 0, fret;

	f = fts_open(paths, FTS_PHYSICAL, NULL);
	if (f == NULL) {
		perror("fts_open");
		exit(2);
	}

	while ((fe = fts_read(f)) != NULL) {
		if (fe->fts_info == FTS_NS) {
			appendfn(fe->fts_path, "cannot traverse");
			ret = 2;
		} else if (fe->fts_info == FTS_F &&
		    (fe->fts_level == 0 ||
		    ((pos = strlen(fe->fts_name)) >= 4 &&
		    strcmp(fe->fts_name + pos - 4, ".pem") == 0))) {
			fret = check_sslcert_file(fe->fts_path);
			if (ret < fret)
				ret = fret;
		}
	}
	fts_close(f);
	return (ret);
}

static unsigned long
getnum(const char *str)
{
	long number;
	char *ep;

	errno = 0;
	number = strtoul(str, &ep, 10);
	if (errno != 0 || *str == '\0' || *ep != '\0') {
		fprintf(stderr, "%s: invalid number\n", str);
		exit(1);
	}
	return (number);
}

int
main(int argc, char *argv[])
{
	int i, ch, ret;

	while ((ch = getopt(argc, argv, "c:w:")) != -1) {
		switch (ch) {
		case 'c':
			dayscritical = getnum(optarg);
			break;
		case 'w':
			dayswarning = getnum(optarg);
			break;
		default:
			usage();
		}
	}
	argv += optind;
	argc -= optind;
	if (argc == 0)
		usage();
	
	tnow = time(NULL);
	tcritical = tnow + dayscritical * 24 * 60 * 60;
	twarning = tnow + dayswarning * 24 * 60 * 60;

	ret = check_sslcert(argv);
	switch (ret) {
	case 0:
		printf("OK - All certificates seem valid\n");
		break;
	case 1:
		printf("WARNING - Offending certificates:%s\n", badfiles);
		break;
	case 2:
		printf("CRITICAL - Offending certificates:%s\n", badfiles);
		break;
	}
	return (ret);
}
