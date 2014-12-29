CFLAGS=-O2 -Wall -Wmissing-prototypes -Wstrict-prototypes -Werror

CHECKS=check_loadtrend check_sslcert check_cdorked_by_shm_size

all: $(CHECKS)

check_sslcert: check_sslcert.o
	$(CC) $(LDFLAGS) -lssl -lcrypto -o check_sslcert check_sslcert.o

clean:
	rm -f *.o *.core *~ $(CHECKS)
