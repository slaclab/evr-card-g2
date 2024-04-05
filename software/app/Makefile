# Variables
BITENV := $(shell getconf LONG_BIT)
CC     := $(CROSS_COMPILE)g++
CFLAGS := -Wall -m$(BITENV) -I$(PWD) -lpthread -lrt -lm

all:
	$(CC) -c $(CFLAGS) tpr.cc -o tpr.o
	$(CC) $(CFLAGS) tpr.o tprtest.cc -o tprtest
	$(CC) $(CFLAGS) tpr.o tprtrig.cc -o tprtrig
	$(CC) $(CFLAGS) tpr.o tprdump.cc -o tprdump
#	$(CC) $(CFLAGS) tpr.o tprloopb.cc -o tprloopb
#	$(CC) $(CFLAGS) tpr.o setupdma.cc -o setupdma
	$(CC) $(CFLAGS) tpr.o evrlock.cc -o evrlock

clean:
	rm -f tpr.o
	rm -f tprtest
	rm -f tprtrig
	rm -f tprdump
#	rm -f tprloopb
#	rm -f setupdma
	rm -f evrlock
