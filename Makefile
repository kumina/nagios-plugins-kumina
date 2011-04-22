CFLAGS=-O2 -Wall -Wmissing-prototypes -Wstrict-prototypes -Werror

CHECKS=check_loadtrend check_sslcert

all: $(CHECKS)

check_sslcert: check_sslcert.o
	$(CC) $(LDFLAGS) -lssl -o check_sslcert check_sslcert.o

clean:
	rm -f *.o *.core *~ $(CHECKS)
