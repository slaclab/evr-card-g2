# Variables
CROSS_COMPILE ?=
BITENV := $(shell getconf LONG_BIT)
CC     := $(CROSS_COMPILE)g++
SRC_DIR ?= $(PWD)
CFLAGS := -Wall -m$(BITENV) -I$(SRC_DIR) -lpthread -lrt -lm


all: MemoryMapTest DatbuffTest PromLoad PromVerify

old_targets:
	$(CC) $(CFLAGS) MemoryMapTest.cpp -o MemoryMapTest
	$(CC) $(CFLAGS) DatbuffTest.cpp   -o DatbuffTest
	$(CC) -c $(CFLAGS) McsRead.cpp -o McsRead.o
	$(CC) -c $(CFLAGS) EvrCardG2Prom.cpp -o EvrCardG2Prom.o
	$(CC) $(CFLAGS) McsRead.o EvrCardG2Prom.o PromLoad.cpp   -o PromLoad
	$(CC) $(CFLAGS) McsRead.o EvrCardG2Prom.o PromVerify.cpp -o PromVerify
	$(CC) $(CFLAGS) McsRead.o EvrCardG2Prom.o PromVersion.cpp -o PromVersion

SUFFIXES: .cpp .o

%.o : $(SRC_DIR)/%.cpp
	$(CC) -c $(CFLAGS) -MD -o $@ $<

MemoryMapTest DatbuffTest PromLoad PromVerify: McsRead.o EvrCardG2Prom.o
MemoryMapTest DatbuffTest PromLoad PromVerify: %: $(SRC_DIR)/%.cpp
	$(CC) McsRead.o EvrCardG2Prom.o -o $@ $< 

clean:
	rm -f *.o
	rm -f MemoryMapTest
	rm -f DatbuffTest
	rm -f PromLoad
	rm -f PromVerify
