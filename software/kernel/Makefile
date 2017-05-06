PGPCARD_HOME := $(shell pwd)
PGPCARD_KVER := $(shell uname -r)

#obj-m := pcie_adc.o
obj-m := tpr.o
#obj-m := tpr_old.o
#obj-m := pcie_tpr.o
#obj-m := pcie_evr.o

all:
	make -C /lib/modules/$(PGPCARD_KVER)/build M=$(PGPCARD_HOME) modules

clean:
	make -C /lib/modules/$(PGPCARD_KVER)/build M=$(PGPCARD_HOME) clean
