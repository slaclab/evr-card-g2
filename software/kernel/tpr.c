//---------------------------------------------------------------------------------
// Title         : Kernel Module For PCI-Express EVR Card
// Project       : PCI-Express EVR
//---------------------------------------------------------------------------------
// File          : pcie_evr.c
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 05/18/2010
//---------------------------------------------------------------------------------
//
//---------------------------------------------------------------------------------
// Copyright (c) 2010 by SLAC National Accelerator Laboratory. All rights reserved.
//---------------------------------------------------------------------------------
// Modification history:
// 05/18/2010: created.
// 10/13/2015: Modified to support unlocked_ioctl if available
//             Added (irq_handler_t) cast in request_irq
//---------------------------------------------------------------------------------
#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/signal.h>
#include <linux/fs.h>
#include <linux/poll.h>
#include <linux/sched.h>
#include <linux/wait.h>
#include <linux/mm.h>
#include <asm/uaccess.h>
#include <asm/atomic.h>
#include <linux/cdev.h>
#include <linux/vmalloc.h>
#include "tpr.h"

/**
 * HAVE_UNLOCKED_IOCTL has been dropped in kernel version 5.9.
 * There is a chance that the removal might be ported back to 5.x.
 * So if HAVE_UNLOCKED_IOCTL is not defined in kernel v5, we define it.
 * This also allows backward-compatibility with kernel < 2.6.11.
 */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0) && !defined(HAVE_UNLOCKED_IOCTL)
#define HAVE_UNLOCKED_IOCTL 1
#endif

#if LINUX_VERSION_CODE >= KERNEL_VERSION(2, 6, 25)
  /* 'ioremap_nocache' was deprecated in kernels >= 5.6, so instead we use 'ioremap' which
  is no-cache by default since kernels 2.6.25. */
#    define IOREMAP_NO_CACHE(address, size) ioremap(address, size)
#else /* KERNEL_VERSION < 2.6.25 */
#    define IOREMAP_NO_CACHE(address, size) ioremap_nocache(address, size)
#endif

#undef TPRDEBUG
//#define TPRDEBUG
#undef TPRDEBUG2

#ifdef TPRDEBUG
#undef KERN_WARNING
#define KERN_WARNING KERN_ALERT
#endif

#ifndef SA_SHIRQ
/* No idea which version this changed in! */
#define SA_SHIRQ IRQF_SHARED
#endif

static __u64 __rdtsc(void);
static __u64 __rdtsc(void){
    __u32 lo, hi;
    __asm__ __volatile__ ("rdtsc" : "=a" (lo), "=d" (hi));
    return ((__u64)hi << 32) | lo;
}

// Function prototypes
int     tpr_open     (struct inode *inode, struct file *filp);
int     tpr_release  (struct inode *inode, struct file *filp);
ssize_t tpr_write    (struct file *filp, const char *buf, size_t count, loff_t *f_pos);
ssize_t tpr_read     (struct file *filp, char *buf, size_t count, loff_t *f_pos);
#ifdef HAVE_UNLOCKED_IOCTL
long    tpr_unlocked_ioctl(struct file *filp, unsigned int cmd, unsigned long arg);
#else
int     tpr_ioctl    (struct inode *inode, struct file *filp, unsigned int cmd, unsigned long arg);
#endif
irqreturn_t tpr_intr (int irq, void *dev_id, struct pt_regs *regs);
int     tpr_probe    (struct pci_dev *pcidev, const struct pci_device_id *dev_id);
void    tpr_remove   (struct pci_dev *pcidev);
int     tpr_init     (void);
void    tpr_exit     (void);
uint    tpr_poll     (struct file *filp, poll_table *wait );
int     tpr_mmap     (struct file *filp, struct vm_area_struct *vma);
int     tpr_fasync   (int fd, struct file *filp, int mode);
void    tpr_vmopen   (struct vm_area_struct *vma);
void    tpr_vmclose  (struct vm_area_struct *vma);

// vm_operations_struct.fault callback function has a different signature
// starting at kernel version 4.11. In this new version the struct vm_area_struct
// in defined as part of the struct vm_fault.
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 11, 0)
int     tpr_vmfault  (struct vm_fault *vmf);
#else
int     tpr_vmfault  (struct vm_area_struct *vma, struct vm_fault *vmf);
#endif

#ifdef CONFIG_COMPAT
long tpr_compat_ioctl(struct file *file, unsigned int cmd, unsigned long arg);
#endif

// PCI device IDs
static struct pci_device_id tpr_ids[] = {
  { PCI_DEVICE(0x1A4A, 0x2011) },  // SLAC TPR
  { 0, }
};

MODULE_LICENSE("GPL");
MODULE_DEVICE_TABLE(pci, tpr_ids);
module_init(tpr_init);
module_exit(tpr_exit);


// PCI driver structure
static struct pci_driver tprDriver = {
  .name     = MOD_NAME,
  .id_table = tpr_ids,
  .probe    = tpr_probe,
  .remove   = tpr_remove,
};

// Define interface routines
struct file_operations tpr_intf = {
   read:    tpr_read,
   write:   tpr_write,
#ifdef HAVE_UNLOCKED_IOCTL
   unlocked_ioctl: tpr_unlocked_ioctl,
#else
   ioctl:   tpr_ioctl,
#endif
#ifdef CONFIG_COMPAT
  compat_ioctl: tpr_compat_ioctl,
#endif

   open:    tpr_open,
   release: tpr_release,
   poll:    tpr_poll,
   fasync:  tpr_fasync,
   mmap:    tpr_mmap,
};

// Virtual memory operations
static struct vm_operations_struct tpr_vmops = {
  open:  tpr_vmopen,
  close: tpr_vmclose,
  fault: tpr_vmfault
};

static int allocBar(struct bar_dev* minor, int major, struct pci_dev* dev, int bar);

#ifdef TPRDEBUG
static void printList(struct shared_tpr *sh)
{
    struct shared_tpr *shared;
    for (shared = sh; shared && shared->next!=shared; shared=shared->next)
        printk(KERN_WARNING "%s         %d [%p %p %p]\n", MOD_NAME, shared->idx, shared, shared->next, shared->prev);
}
#endif

// Open Returns 0 on success, error code on failure
int tpr_open(struct inode *inode, struct file *filp) {
  struct tpr_dev *   dev;
  struct TprReg*     reg;
  int                minor;

  // Extract structure for card
  dev = container_of(inode->i_cdev, struct tpr_dev, cdev);
  minor = iminor(inode);

  printk(KERN_WARNING "%s: Open: Minor %i.  Maj %i\n",
	 MOD_NAME, minor, dev->major);

  if (minor < MOD_SHARED || minor == (MOD_SHARED+1)) { // A single channel or BSA
    struct shared_tpr *shared;
    spin_lock(&dev->lock);
    shared = dev->freelist;
    if (shared)
        dev->freelist = shared->next;
    spin_unlock(&dev->lock);
    if (!shared) {
      printk(KERN_WARNING "%s: Open: module open failed.  Too many opens. Maj=%i, Min=%i.\n",
             MOD_NAME, dev->major, (unsigned)minor);
      return (ERROR);
    }
    filp->private_data = shared;
    shared->parent = dev;
#ifdef TPRDEBUG
    printk(KERN_WARNING "%s: Open: minor %d opened as index %d.\n",
           MOD_NAME, minor, shared->idx);
#endif

    if (minor < MOD_SHARED) {
        if (!dev->shared[minor]) {  // The first open for this minor device.
            printk(KERN_WARNING "%s: Open: Enable minor. Maj=%i, Min=%i.\n",
                   MOD_NAME, dev->major, (unsigned)minor);
            dev->minors = dev->minors | (1<<minor);
            //
            //  Enable the dma for this channel
            //
            reg = (struct TprReg*)(dev->bar[0].reg);
            reg->channel[minor].control = reg->channel[minor].control | (1<<2);
            reg->irqControl = 1;
            dev->irqEnable++;
        }
        shared->minor = minor;
        spin_lock(&dev->lock);
        shared->next = dev->shared[minor];
        if (shared->next)
            shared->next->prev = shared;
        shared->prev = NULL;
        dev->shared[minor] = shared;
        spin_unlock(&dev->lock);
#ifdef TPRDEBUG
        printk(KERN_WARNING "%s         dev->shared[%d]\n", MOD_NAME, minor);
        printList(dev->shared[minor]);
#endif
    }
    else if (minor == MOD_SHARED+1) {
        shared->minor = -1;
        spin_lock(&dev->lock);
        shared->next = dev->bsa;
        if (shared->next)
            shared->next->prev = shared;
        shared->prev = NULL;
        dev->bsa = shared;
        spin_unlock(&dev->lock);
#ifdef TPRDEBUG
        printk(KERN_WARNING "%s: BSA list. Maj=%i, Min=%i.\n",
               MOD_NAME, dev->major, (unsigned)shared->minor);
        printList(dev->bsa);
#endif
    }
  }
  else if (minor == MOD_SHARED) {      // Control
    if (dev->master.parent) {
      printk(KERN_WARNING "%s: Open: module open failed.  Device already open. Maj=%i, Min=%i.\n",
             MOD_NAME, dev->major, (unsigned)minor);
      return (ERROR);
    }

    dev->master.parent = dev;
    filp->private_data = &dev->master;
  }
  else {
    printk(KERN_WARNING "%s: Open: module open failed.  Minor number out of range. Maj=%i, Min=%i.\n",
           MOD_NAME, dev->major, (unsigned)minor);
    return (ERROR);
  }

  return SUCCESS;
}


// tpr_release
// Called when the device is closed
// Returns 0 on success, error code on failure
int tpr_release(struct inode *inode, struct file *filp) {
  int i;
  struct shared_tpr *shared = (struct shared_tpr*)filp->private_data;
  struct TprReg* reg;
  struct tpr_dev *dev;

  if (!shared->parent) {
    printk("%s: Release: module close failed. Already closed.\n",MOD_NAME);
    return ERROR;
  }

  dev = (struct tpr_dev*)shared->parent;
  if (shared->idx < 0) {                      // Master
      // Nothing to do!
  }
  else {                                      // Single channel or BSA
    spin_lock(&dev->lock);
    if (shared->prev)
        shared->prev->next = shared->next;
    if (shared->next)
        shared->next->prev = shared->prev;

    if (shared->minor < 0) {
        if(!shared->prev) dev->bsa = shared->next;
#ifdef TPRDEBUG
        printk(KERN_WARNING "%s: BSA list. Maj=%i, Min=%i.\n",
               MOD_NAME, dev->major, (unsigned)shared->minor);
        printList(dev->bsa);
#endif
    } else {                 // Single channel
        if(!shared->prev) dev->shared[shared->minor] = shared->next;
        if (!dev->shared[shared->minor]) {       // Last one leaving, shut out the lights...
          i = shared->minor;
          reg = (struct TprReg*)shared->parent->bar[0].reg;
          reg->channel[i].control = reg->channel[0].control & ~(1<<2);
          dev->minors = dev->minors & ~(1<<i);
          printk(KERN_WARNING "%s: Release: Disable minor. Maj=%i, Min=%i.\n",
                 MOD_NAME, dev->major, (unsigned)shared->minor);
        }
#ifdef TPRDEBUG
        printk(KERN_WARNING "%s         dev->shared[%d]\n", MOD_NAME, shared->minor);
        printList(dev->shared[shared->minor]);
#endif
    }

    //  Put it back on the freelist
    shared->prev = NULL;
    if (dev->freelist) {
      shared->next = dev->freelist;
    }
    else {
      shared->next = NULL;
    }
    dev->freelist = shared;

    spin_unlock(&dev->lock);
  }

  printk("%s: Release: Major %u: irqEnable %u, irqDisable %u, irqCount %u, irqNoReq %u\n",
	   MOD_NAME, shared->parent->major,
	   dev->irqEnable,
	   dev->irqDisable,
	   dev->irqCount,
	   dev->irqNoReq);

  printk("%s: Release: Major %u: dmaCount %u, dmaEvent %u, dmaBsaChan %u, dmaBsaCtrl %u\n",
	   MOD_NAME, shared->parent->major,
	   dev->dmaCount,
	   dev->dmaEvent,
	   dev->dmaBsaChan,
	   dev->dmaBsaCtrl);

  //  Unlink
  shared->parent = NULL;

  return SUCCESS;
}


// tpr_write
// noop.
ssize_t tpr_write(struct file *filp, const char *buffer, size_t count, loff_t *f_pos) {
  return(0);
}


// tpr_read
// Returns bit mask of queues with data pending.
ssize_t tpr_read(struct file *filp, char *buffer, size_t count, loff_t *f_pos)
{
  ssize_t retval = 0;
  struct shared_tpr *shared = ((struct shared_tpr *) filp->private_data);
  __u32 pendingirq;

  do {
    if (count < sizeof(pendingirq))
      break;
    while (!shared->pendingirq) {
      if (filp->f_flags & O_NONBLOCK)
        return -EAGAIN;
#ifdef TPRDEBUG2
      printk(KERN_WARNING "%s: sleeping %d for %d\n", MOD_NAME, shared->idx, shared->minor);
#endif
      if (wait_event_interruptible(shared->waitq, shared->pendingirq))
        return -ERESTARTSYS;
    }
    pendingirq = (__u32) test_and_clear_bit(0, (volatile unsigned long*)&shared->pendingirq);
#ifdef TPRDEBUG2
    printk(KERN_WARNING "%s: woke up %d for %d, pendingirq=%d\n", MOD_NAME, shared->idx, shared->minor, pendingirq);
#endif
    if (copy_to_user(buffer, &pendingirq, sizeof(pendingirq))) {
      retval = -EFAULT;
      break;
    }
    *f_pos = *f_pos + sizeof(pendingirq);
    retval = sizeof(pendingirq);
  } while(0);

  return retval;
}


// tpr_ioctl
#ifdef HAVE_UNLOCKED_IOCTL
long tpr_unlocked_ioctl(struct file *filp, unsigned int cmd, unsigned long arg) {
#else
int tpr_ioctl(struct inode *inode, struct file *filp, unsigned int cmd, unsigned long arg) {
#endif

  // lcls-i ioctls only?

  return(ERROR);
}

#ifdef CONFIG_COMPAT
long tpr_compat_ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
#ifdef HAVE_UNLOCKED_IOCTL
  return tpr_unlocked_ioctl(file, cmd, arg);
#else
  return tpr_ioctl(NULL, file, cmd, arg);
#endif
}
#endif

// Bottom half of IRQ Handler
static void tpr_handle_dma(unsigned long arg)
{
  struct tpr_dev* dev = &gDevices[arg];
  struct TprQueues* tprq = dev->amem;

  struct RxBuffer*  next;
  __u32*            dptr;
  __u32             mtyp, ich, mch, wmask=0;
  __u64             tsc;
  struct TprEntry  *pEntry;

  next = dev->rxPend;

  //  Check the "dma done" bit.
  while (test_and_clear_bit(31, (volatile unsigned long*)next->buffer)) {

    dptr = (__u32*)next->buffer;

    while( ((dptr[0]>>16)&0xf) != END_TAG ) {

      dev->dmaCount++;
      tsc = __rdtsc();

      //  Check if a drop preceded us
      if ( dptr[0] & (0x808<<20)) {
        //  How to propagate this?
        //  Write a drop message to all channels?
        tprq->fifofull = 1;  // ??
      }

      //  Check the message type
      mtyp = (dptr[0]>>16)&0xf;
      switch (mtyp) {
      case BSACNTL_TAG:
#ifdef TPRDEBUG2
          printk(KERN_WARNING "%s: BSA_CTRL %lld\n", MOD_NAME, tprq->bsawp);
#endif
          dev->dmaBsaCtrl++;
          wmask = wmask | (1 << (MOD_SHARED+1));
          pEntry = &tprq->bsaq[tprq->bsawp & (MAX_TPR_BSAQ-1)];
          memcpy(pEntry, dptr, BSACNTL_MSGSZ);
          pEntry->fifo_tsc = tsc;
          tprq->bsawp++;
          dptr += BSACNTL_MSGSZ>>2;
          break;
      case BSAEVNT_TAG:
#ifdef TPRDEBUG2
          printk(KERN_WARNING "%s: BSA_EVNT %lld\n", MOD_NAME, tprq->bsawp);
#endif
          dev->dmaBsaChan++;
          wmask = wmask | (1 << (MOD_SHARED+1));
          pEntry = &tprq->bsaq[tprq->bsawp & (MAX_TPR_BSAQ-1)];
          memcpy(pEntry, dptr, BSAEVNT_MSGSZ);
          pEntry->fifo_tsc = tsc;
          tprq->bsawp++;
          dptr += BSAEVNT_MSGSZ>>2;
          break;
      case EVENT_TAG:
#ifdef TPRDEBUG2
          printk(KERN_WARNING "%s: EVENT\n", MOD_NAME);
#endif
          dev->dmaEvent++;
          mch = (dptr[0]>>0)&((1<<MOD_SHARED)-1);
          if (((dptr[1]<<2)+8)!=EVENT_MSGSZ) {
            printk(KERN_WARNING  "%s: unexpected event dma size %08x(%08x)...truncating.\n", MOD_NAME, EVENT_MSGSZ,(dptr[1]<<2)+8);
            break;
          }
          pEntry = &tprq->allq[tprq->gwp & (MAX_TPR_ALLQ-1)];
          memcpy(pEntry, dptr, EVENT_MSGSZ);
          pEntry->fifo_tsc = tsc;
          dptr += EVENT_MSGSZ>>2;
          wmask = wmask | mch;
          for( ich=0; mch; ich++) {
              if (mch & (1<<ich)) {
                  mch = mch & ~(1<<ich);
                  tprq->allrp[ich].idx[tprq->allwp[ich] & (MAX_TPR_ALLQ-1)] = tprq->gwp;
                  tprq->allwp[ich]++;
              }
          }
          tprq->gwp++;
          break;
      default:
          printk(KERN_WARNING  "%s: handle unknown msg %08x:%08x\n", MOD_NAME, dptr[0], dptr[1]);
          break;
      }
    }

    //  Queue the dma buffer back to the hardware
    ((struct TprReg*)dev->bar[0].reg)->rxFree[0] = next->dma;

    next = (struct RxBuffer*)next->lh.next;
  }

  dev->rxPend = next;

  //  Wake the apps
  for( ich=0; ich<MOD_SHARED; ich++) {
    if ((wmask&(1<<ich)) && dev->shared[ich]) {
      struct shared_tpr *shared;
      for (shared = dev->shared[ich]; shared; shared = shared->next) {
        set_bit(0, (volatile unsigned long*)&shared->pendingirq);
#ifdef TPRDEBUG2
        printk(KERN_WARNING "%s: set pendingirq for %d == %ld\n", MOD_NAME, ich, shared->pendingirq);
#endif
        wake_up(&shared->waitq);
      }
    }
  }

  if (wmask & (1 << (MOD_SHARED+1))) {
      struct shared_tpr *shared;
      for (shared = dev->bsa; shared; shared = shared->next) {
        set_bit(0, (volatile unsigned long*)&shared->pendingirq);
#ifdef TPRDEBUG2
        printk(KERN_WARNING "%s: set pendingirq for %d == %ld\n", MOD_NAME, ich, shared->pendingirq);
#endif
        wake_up(&shared->waitq);
      }
  }

  //  Enable the interrupt
  if (dev->minors) {
    ((struct TprReg*)dev->bar[0].reg)->irqControl = 1;
    dev->irqEnable++;
  }
}


// IRQ Handler
irqreturn_t tpr_intr(int irq, void *dev_id, struct pt_regs *regs) {
  unsigned int stat;
  unsigned int handled=0;

  struct tpr_dev *dev = (struct tpr_dev *)dev_id;

  //
  //  Handle the interrupt:
  //  wakeup the tasklet that copies the dma data into the sw queues
  //
  stat = ((struct TprReg*)dev->bar[0].reg)->irqStatus;
  if ( (stat & 1) != 0 ) {
    // Disable interrupts
    dev->irqCount++;
    dev->irqDisable++;
    if (((struct TprReg*)dev->bar[0].reg)->irqControl==0)
      dev->irqNoReq++;
    ((struct TprReg*)dev->bar[0].reg)->irqControl = 0;
    tasklet_schedule(&dev->dma_task);
    handled=1;
  }

  if (handled==0) return(IRQ_NONE);

  return(IRQ_HANDLED);
}

uint tpr_poll(struct file *filp, poll_table *wait ) {
  struct shared_tpr *dev = (struct shared_tpr *)filp->private_data;

  poll_wait(filp, &(dev->waitq), wait);

  if (dev->pendingirq & 1)
    return(POLLIN | POLLRDNORM); // Readable

  return(0);
}



// Probe device
int tpr_probe(struct pci_dev *pcidev, const struct pci_device_id *dev_id) {
   int i, idx, res;
   dev_t chrdev = 0;
   struct tpr_dev* dev;
   struct TprReg*  tprreg;
   struct pci_device_id *id = (struct pci_device_id *) dev_id;

   // We keep device instance number in id->driver_data
   id->driver_data = -1;

   // Find empty structure
   for (i = 0; i < MAX_PCI_DEVICES; i++) {
     if (gDevices[i].bar[0].baseHdwr == 0) {
       id->driver_data = i;
       break;
     }
   }

   // Overflow
   if (id->driver_data < 0) {
     printk(KERN_WARNING  "%s: Probe: Too Many Devices.\n", MOD_NAME);
     return -EMFILE;
   }
   dev = &gDevices[id->driver_data];

   dev->qmem = (void *)vmalloc(sizeof(struct TprQueues) + PAGE_SIZE); // , GFP_KERNEL);
   if (!dev->qmem) {
     printk(KERN_WARNING  MOD_NAME ": could not allocate %lu.\n", sizeof(struct TprQueues) + PAGE_SIZE);
     return -ENOMEM;
   }

   printk(KERN_WARNING  MOD_NAME ": Allocated %lu at %p.\n", sizeof(struct TprQueues) + PAGE_SIZE, dev->qmem);
   memset(dev->qmem, 0, sizeof(struct TprQueues) + PAGE_SIZE);
   dev->amem = (void *)((long)(dev->qmem + PAGE_SIZE - 1) & PAGE_MASK);
   ((struct TprQueues*) dev->amem)->fifofull = 0xabadcafe;

   printk(KERN_WARNING  MOD_NAME ": amem = %p.\n", dev->amem);

   // Allocate device numbers for character device.
   res = alloc_chrdev_region(&chrdev, 0, MOD_MINORS, MOD_NAME);
   if (res < 0) {
     printk(KERN_WARNING  "%s: Probe: Cannot register char device\n", MOD_NAME);
     return res;
   }

   // Initialize device structure
   dev->major           = MAJOR(chrdev);
   cdev_init(&dev->cdev, &tpr_intf);
   dev->cdev.owner      = THIS_MODULE;
   dev->bar[0].baseHdwr = 0;
   dev->bar[0].baseLen  = 0;
   dev->bar[0].reg      = 0;
   dev->dma_task.func   = tpr_handle_dma;
   dev->dma_task.data   = i;
   dev->minors          = 0;
   dev->irqEnable       = 0;
   dev->irqDisable      = 0;
   dev->irqCount        = 0;
   dev->irqNoReq        = 0;
   dev->dmaCount        = 0;
   dev->dmaEvent        = 0;
   dev->dmaBsaChan      = 0;
   dev->dmaBsaCtrl      = 0;

   // Add device
   if ( cdev_add(&dev->cdev, chrdev, MOD_MINORS) )
     printk(KERN_WARNING  "%s: Probe: Error adding device Maj=%i\n", MOD_NAME, dev->major);

   // Enable devices
   if (pci_enable_device(pcidev)) {
     printk(KERN_WARNING  "%s: Could not enable device \n", MOD_NAME);
     return (ERROR);
   }

   if (allocBar(&dev->bar[0], dev->major, pcidev, 0) == ERROR)
     return (ERROR);

   // Get IRQ from pci_dev structure.
   dev->irq = pcidev->irq;
   printk(KERN_WARNING  "%s: Init: IRQ %d Maj=%i\n", MOD_NAME, dev->irq, dev->major);

   for( i = 0; i < OPEN_SHARES; i++) {
     if (i)
         dev->all_shares[i].next = &dev->all_shares[i-1];
     else
         dev->all_shares[i].next = NULL;
     dev->all_shares[i].prev = NULL;   // The freelist is singly linked!
     dev->all_shares[i].parent = NULL;
     dev->all_shares[i].idx = i;
     init_waitqueue_head(&dev->all_shares[i].waitq);
     spin_lock_init(&dev->all_shares[i].lock);
   }
   for( i = 0; i < MOD_SHARED; i++) {
     dev->shared[i] = NULL;
   }
   dev->bsa = NULL;
   spin_lock_init(&dev->lock);
   dev->freelist = &dev->all_shares[OPEN_SHARES-1];

   dev->master.parent = NULL;
   dev->master.idx    = -1;
   init_waitqueue_head(&dev->master.waitq);
   spin_lock_init     (&dev->master.lock);

   // Device initialization
   tprreg = (struct TprReg* )(dev->bar[0].reg);

   printk(KERN_WARNING  "%s: Init: FpgaVersion %08x Maj=%i\n",
          MOD_NAME, tprreg->FpgaVersion, dev->major);

   tprreg->xbarOut[2] = 1;  // Set LCLS-II timing input

   tprreg->irqControl = 0;  // Disable interrupts

   for( i=0; i<TR_CHANNELS; i++) {
     tprreg->trigger[i].control=0;  // Disable all channels
   }

   // FIFO size for detecting DMA complete
   tprreg->rxFifoSize = NUMBER_OF_RX_BUFFERS-1;
   tprreg->rxMaxFrame = BUF_SIZE | (1<<31);

   // Init RX Buffers
   dev->rxBuffer   = (struct RxBuffer **) vmalloc(NUMBER_OF_RX_BUFFERS * sizeof(struct RxBuffer *));

   for ( idx=0; idx < NUMBER_OF_RX_BUFFERS; idx++ ) {
     dev->rxBuffer[idx] = (struct RxBuffer *) vmalloc(sizeof(struct RxBuffer ));
     if ((dev->rxBuffer[idx]->buffer = pci_alloc_consistent(pcidev, BUF_SIZE, &(dev->rxBuffer[idx]->dma))) == NULL ) {
       printk(KERN_WARNING "%s: Init: unable to allocate rx buffer [%d/%d]. Maj=%i\n",
              MOD_NAME, idx, NUMBER_OF_RX_BUFFERS, dev->major);
       break;
     }

     clear_bit(31,(volatile unsigned long*)dev->rxBuffer[idx]->buffer);

     // Add to RX queue
     if (idx == 0) {
       dev->rxFree = dev->rxBuffer[idx];
       INIT_LIST_HEAD(&dev->rxFree->lh);
     }
     else
       list_add_tail( &dev->rxBuffer[idx]->lh,
                      &dev->rxFree->lh );
     tprreg->rxFree[0] = dev->rxBuffer[idx]->dma;
   }

   dev->rxPend = dev->rxFree;

   // Request IRQ from OS.
   if (request_irq(dev->irq, (irq_handler_t) tpr_intr, SA_SHIRQ, MOD_NAME, dev) < 0 ) {
     printk(KERN_WARNING  "%s: Open: Unable to allocate IRQ. Maj=%i", MOD_NAME, dev->major);
     return (ERROR);
   }

   printk(KERN_ALERT "%s: Init: Driver is loaded. Maj=%i\n", MOD_NAME,dev->major);
   return SUCCESS;
}


void tpr_remove(struct pci_dev *pcidev) {
   int  i, idx;
   struct tpr_dev *dev = NULL;
   struct TprReg*  tprreg;

   // Look for matching device
   for (i = 0; i < MAX_PCI_DEVICES; i++) {
     if ( gDevices[i].bar[0].baseHdwr == pci_resource_start(pcidev, 0)) {
       dev = &gDevices[i];
       break;
     }
   }

   // Device not found
   if (dev == NULL) {
     printk(KERN_WARNING  "%s: Remove: Device Not Found.\n", MOD_NAME);
   }
   else {
     unsigned long flags;

     spin_lock_irqsave(&dev->lock, flags);
     // At this point, there might be an IRQ/tasklet running.  We're blocking
     // another IRQ from coming though.

     // Release IRQ first, so we don't call tpr_intr any more!
     free_irq(dev->irq, dev);

     // At this point, we might have had an IRQ, so the tasklet might be scheduled.
     // We won't get another one past this though.
     tasklet_kill(&dev->dma_task);

     // No more tasklet operations now.  And if we get an IRQ, it won't be routed
     // correctly anyway.

     // Turn off the interrupts!
     tprreg = (struct TprReg*)dev->bar[0].reg;
     tprreg->irqControl = 0;

     // We should be finished now.
     spin_unlock_irqrestore(&dev->lock, flags);

     //  Clear the registers
     for( i=0; i<RO_CHANNELS; i++)
       tprreg->channel[i].control=0;  // Disable event selection, DMA
     for( i=0; i<TR_CHANNELS; i++)
       tprreg->trigger[i].control=0;  // Disable TTL

     //  Free all rx buffers awaiting read.
     tprreg->rxMaxFrame = 0;

     //  Free the rx buffer memory.
     for ( idx=0; idx < NUMBER_OF_RX_BUFFERS; idx++ ) {
       if (dev->rxBuffer[idx]->dma != 0) {
         pci_free_consistent( pcidev, BUF_SIZE, dev->rxBuffer[idx]->buffer, dev->rxBuffer[idx]->dma);
         if (dev->rxBuffer[idx]) {
           vfree(dev->rxBuffer[idx]);
         }
       }
     }
     vfree(dev->rxBuffer);
     vfree(dev->qmem);

     // Unmap
     iounmap(dev->bar[0].reg);

     // Release memory region
     release_mem_region(dev->bar[0].baseHdwr, dev->bar[0].baseLen);

     // Unregister Device Driver
     cdev_del(&dev->cdev);
     unregister_chrdev_region(MKDEV(dev->major,0), MOD_MINORS);

     // Disable device
     pci_disable_device(pcidev);
     dev->bar[0].baseHdwr = 0;
     printk(KERN_ALERT "%s: Remove: Driver is unloaded. Maj=%i\n", MOD_NAME, dev->major);
   }
 }


 // Memory map
int tpr_mmap(struct file *filp, struct vm_area_struct *vma)
{
   struct shared_tpr *shared = (struct shared_tpr *)filp->private_data;

   unsigned long offset = vma->vm_pgoff << PAGE_SHIFT;
   unsigned long vsize  = vma->vm_end - vma->vm_start;
   unsigned long physical;

   int result;

   if (shared->idx < 0) {
     if (vsize > shared->parent->bar[0].baseLen) {
       printk(KERN_WARNING "%s: Mmap: mmap vsize %08x, baseLen %08x. Maj=%i\n", MOD_NAME,
              (unsigned int) vsize, (unsigned int) shared->parent->bar[0].baseLen, shared->parent->major);
       return -EINVAL;
     }
     physical = ((unsigned long) shared->parent->bar[0].baseHdwr) + offset;
     result = io_remap_pfn_range(vma, vma->vm_start, physical >> PAGE_SHIFT,
                                 vsize, vma->vm_page_prot);
     if (result) return -EAGAIN;
   }
   else {
     if (vsize > TPR_SH_MEM_WINDOW) {
       printk(KERN_WARNING "%s: Mmap: mmap vsize %08x, TPR_SH_MEM_WINDOW %08x. Maj=%i\n", MOD_NAME,
              (unsigned int) vsize, (unsigned int)TPR_SH_MEM_WINDOW, shared->parent->major);
       return -EINVAL;
     }
     /* Handled by tpr_vmfault */
   }

   vma->vm_ops = &tpr_vmops;
   vma->vm_private_data = shared->parent;
   tpr_vmopen(vma);
   return 0;
}


void tpr_vmopen(struct vm_area_struct *vma)
{
  struct tpr_dev* dev = vma->vm_private_data;
  dev->vmas++;
}


void tpr_vmclose(struct vm_area_struct *vma)
{
  struct tpr_dev* dev = vma->vm_private_data;
  dev->vmas--;
}

// vm_operations_struct.fault callback function has a different signature
// starting at kernel version 4.11. In this new version the struct vm_area_struct
// in defined as part of the struct vm_fault.
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 11, 0)
int tpr_vmfault(struct vm_fault* vmf)
#else
int tpr_vmfault(struct vm_area_struct* vma,
                struct vm_fault* vmf)
#endif
{
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 11, 0)
  struct tpr_dev* dev = (struct tpr_dev *) vmf->vma->vm_private_data;
#else
  struct tpr_dev* dev = vma->vm_private_data;
#endif
  void* pageptr;

  pageptr = dev->amem + (vmf->pgoff << PAGE_SHIFT);

  vmf->page = vmalloc_to_page(pageptr);

  get_page(vmf->page);

  return SUCCESS;
}

 // Flush queue
int tpr_fasync(int fd, struct file *filp, int mode) {
   struct shared_tpr *shared = (struct shared_tpr *)filp->private_data;
   return fasync_helper(fd, filp, mode, &(shared->parent->async_queue));
}

int allocBar(struct bar_dev* minor, int major, struct pci_dev* pcidev, int bar)
{
   // Get Base Address of registers from pci structure.
   minor->baseHdwr = pci_resource_start (pcidev, bar);
   minor->baseLen  = pci_resource_len   (pcidev, bar);
   printk(KERN_WARNING "%s: Init: Alloc bar %i [%lu/%lu].\n", MOD_NAME, bar,
	  minor->baseHdwr, minor->baseLen);

   request_mem_region(minor->baseHdwr, minor->baseLen, MOD_NAME);
   printk(KERN_WARNING  "%s: Probe: Found card. Bar%d. Maj=%i\n",
	  MOD_NAME, bar, major);

   // Remap the I/O register block so that it can be safely accessed.
   minor->reg = IOREMAP_NO_CACHE(minor->baseHdwr, minor->baseLen);
   if (! minor->reg ) {
     printk(KERN_WARNING "%s: Init: Could not remap memory Maj=%i.\n", MOD_NAME,major);
     return (ERROR);
   }

   return SUCCESS;
}

 // Init Kernel Module
int tpr_init(void) {

   /* Allocate and clear memory for all devices. */
   memset(gDevices, 0, sizeof(struct tpr_dev)*MAX_PCI_DEVICES);

   printk(KERN_WARNING "%s: Init: tpr init.\n", MOD_NAME);

   // Register driver
   return(pci_register_driver(&tprDriver));
}


 // Exit Kernel Module
void tpr_exit(void) {
   printk(KERN_WARNING "%s: Exit: tpr exit.\n", MOD_NAME);
   pci_unregister_driver(&tprDriver);
}


