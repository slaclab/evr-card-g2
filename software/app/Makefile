# Variables
ARCH   := $(shell getconf LONG_BIT)
CC     := g++
CFLAGS := -Wall -m$(ARCH) -I$(PWD) -lpthread -lrt -lm

all:
	$(CC) -c $(CFLAGS) tpr.cc -o tpr.o
	$(CC) $(CFLAGS) tpr.o tprtest.cc -o tprtest 

clean:
	rm -f tpr.o
	rm -f tprtest
