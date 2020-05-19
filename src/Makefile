CFLAGS=-O3 -W -Wall
CC=gcc
O=../bin

all: $O/uevent

$O:
	mkdir -p $O

$O/uevent: uevent.o | $O
	$(CC) $(LDFLAGS) -o $@ $^



