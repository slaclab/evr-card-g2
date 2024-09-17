PGPCARD_HOME := $(shell pwd)
PGPCARD_KVER := $(shell uname -r)
ARCH := $(shell uname -m)
CROSS_COMPILE :=
KERNELDIR := /lib/modules/$(PGPCARD_KVER)/build
HOME := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

ifndef GITV
    GITT := $(shell cd $(HOME); git describe --tags)
    GITD := $(shell cd $(HOME); git status --short -uno | wc -l)
    GITV := $(if $(filter $(GITD),0),$(GITT),$(GITT)-dirty)
endif

ccflags-y += -DGITV=\"$(GITV)\"

#obj-m := pcie_adc.o
obj-m := tpr.o
#obj-m := tpr_old.o
#obj-m := pcie_tpr.o
#obj-m := pcie_evr.o

all:
	@echo $(GITV)
	make ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(KERNELDIR) M=$(PGPCARD_HOME) modules

clean:
	make ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(KERNELDIR) M=$(PGPCARD_HOME) clean
