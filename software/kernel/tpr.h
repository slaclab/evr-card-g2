#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
#include <linux/poll.h>
#include <linux/cdev.h>
#include <asm/uaccess.h>
#include<linux/spinlock.h>
#include<linux/version.h>
#include <linux/types.h>

#define MOD_NAME "tpr"

// Error codes
#define SUCCESS 0
#define ERROR   -1

// TPR message tags
#define EVENT_TAG    0
#define BSACNTL_TAG  1
#define BSAEVNT_TAG  2
#define END_TAG     15

#define EVENT_MSGSZ    92
#define BSACNTL_MSGSZ  44
#define BSAEVNT_MSGSZ  44

/*
 * The data for a particular application on a shared device.
 */
struct shared_tpr {
  struct tpr_dev* parent;      /* Set if in use, otherwise NULL */
  int             idx;         /* The index of this structure in parent->all_shares */
  int             minor;       /* The index of list containing this structure in parent->shared */
  u32             irqmask;     /* The IRQs this client wants to see. */
  unsigned long   pendingirq;  /* IRQs still to be delivered. */
  wait_queue_head_t waitq;
  spinlock_t      lock;
  struct shared_tpr *next;
  struct shared_tpr *prev;
};

struct bar_dev {
  ulong             baseHdwr;
  ulong             baseLen;
  void*             reg;
};

#define MOD_SHARED 14
#define OPEN_SHARES 256

struct tpr_dev {
  int               major;
  struct cdev       cdev;
  struct fasync_struct* async_queue;
  int               irq;
  int               vmas;
  void*             qmem;
  void*             amem;           /* Page-aligned memory for the queues. */
  struct bar_dev    bar[1];
  struct shared_tpr master;
  struct shared_tpr all_shares[OPEN_SHARES];
  struct shared_tpr *shared[MOD_SHARED];
  struct shared_tpr *bsa;
  struct tasklet_struct dma_task;
  spinlock_t        lock;
  struct shared_tpr *freelist;
  uint              minors;
  uint              irqEnable;      /* Interrupt handling counters */
  uint              irqDisable;
  uint              irqCount;
  uint              irqNoReq;
  uint              dmaCount;      /* Count DMA messages */
  uint              dmaEvent;
  uint              dmaBsaChan;
  uint              dmaBsaCtrl;

  // One list, two pointers into the list
  // The list needs only to be singly-linked
  struct RxBuffer** rxBuffer;
  struct RxBuffer*  rxFree;
  struct RxBuffer*  rxPend;
};

// Max number of devices to support
#define MAX_PCI_DEVICES 8

// Global Variable
struct tpr_dev gDevices[MAX_PCI_DEVICES];

#define MOD_MINORS (MOD_SHARED+2)

/* These must be powers of two!!! */
#define MAX_TPR_ALLQ (32*1024)
#define MAX_TPR_BSAQ  1024
#define MSG_SIZE      32

// DMA Buffer Size, Bytes (could be as small as 512B)
#define BUF_SIZE 4096
#define NUMBER_OF_RX_BUFFERS 1023

#define RO_CHANNELS 14
#define TR_CHANNELS 12

struct TprEntry {
  u32 word[MSG_SIZE];
};

struct TprQIndex {
  long long idx[MAX_TPR_ALLQ];
};

//
//  Maintain an indexed list into the tprq for each channel
//  That way, applications of varied rates can jump to the next relevant entry
//  Consider copying master queue to individual channel queues to reduce RT reqt
//
struct TprQueues {
  struct TprEntry  allq  [MAX_TPR_ALLQ]; // master queue of shared messages
  struct TprEntry  bsaq  [MAX_TPR_BSAQ]; // queue of BSA messages
  struct TprQIndex allrp [MOD_SHARED];   // indices into allq
  long long        allwp [MOD_SHARED];   // write pointer into allrp
  long long        bsawp;                // write pointer into bsaq
  long long        gwp;
  int              fifofull;
};

#define TPR_SH_MEM_WINDOW   ((sizeof(struct TprQueues) + PAGE_SIZE) & PAGE_MASK)

struct TprReg {
  __u32 reserved_0[0x10000>>2];
  __u32 FpgaVersion;
  __u32 reserved_04[(0x30000>>2)-1];
  __u32 xbarOut[4]; // 0x40000
  __u32 reserved_40010[(0x20000>>2)-4];
  __u32 irqControl; // 0x60000
  __u32 irqStatus;
  __u32 reserved_60008[0x3f8>>2];
  //  PcieRxDesc   0x60400
  __u32 rxFree    [16];   // WO 0x400 Write Desc/Address
  __u32 rxFreeStat[16];   // RO 0x440 Free FIFO (31:31 full, 30:30 valid, 9:0 count)
  __u32 reserved  [32];
  __u32 rxMaxFrame;       // RW 0x500 (31:31 freeEnable, 23:0 maxFrameSize)
  __u32 rxFifoSize;       // RW 0x504 Buffers per FIFO
  __u32 rxCount ;         // RO 0x508 (rxCount)
  __u32 lastDesc;         // RO 0x50C (lastDesc)

  __u32 reserved_60510[((0x20000-0x510)>>2)];
  struct ChReg {    // 0x80000
    __u32 control;
    __u32 reserved[0x3ff];
  } channel[32];
  struct TrReg {    // 0xa0000
    __u32 control;
    __u32 reserved[0x3ff];
  } trigger[32];
};

// Structure for RX buffers
struct RxBuffer {
  struct list_head lh;
  dma_addr_t  dma;
  unchar*     buffer;
};
