#CFLAGS=-O2 -Wall -Wmissing-prototypes -Wstrict-prototypes -Werror
LDFLAGS=-lssl

CHECKS=check_sslcert

all: $(CHECKS)

clean:
	rm -f *.o *.core *~ $(CHECKS)
