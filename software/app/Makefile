# Variables
BITENV := $(shell getconf LONG_BIT)
CC     := $(CROSS_COMPILE)g++
CFLAGS := -Wall -m$(BITENV) -I$(PWD) -lpthread -lrt -lm

all:
	$(CC) -c $(CFLAGS) tpr.cc -o tpr.o
	$(CC) $(CFLAGS) tpr.o tprtest.cc -o tprtest
	$(CC) $(CFLAGS) tpr.o evgasync.cc -o evgasync

clean:
	rm -f tpr.o
	rm -f tprtest
	rm -f evgasync
