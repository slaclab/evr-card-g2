# Variables
BITENV := $(shell getconf LONG_BIT)
CC     := $(CROSS_COMPILE)g++
CFLAGS := -Wall -m$(BITENV) -I$(PWD) -lpthread -lrt -lm

all:
	$(CC) $(CFLAGS) MemoryMapTest.cpp -o MemoryMapTest
	$(CC) $(CFLAGS) DatbuffTest.cpp   -o DatbuffTest
	$(CC) -c $(CFLAGS) McsRead.cpp -o McsRead.o
	$(CC) -c $(CFLAGS) EvrCardG2Prom.cpp -o EvrCardG2Prom.o
	$(CC) $(CFLAGS) McsRead.o EvrCardG2Prom.o PromLoad.cpp   -o PromLoad
	$(CC) $(CFLAGS) McsRead.o EvrCardG2Prom.o PromVerify.cpp -o PromVerify

clean:
	rm -f MemoryMapTest
	rm -f DatbuffTest
	rm -f McsRead.o
	rm -f EvrCardG2Prom.o
	rm -f PromLoad
	rm -f PromVerify
