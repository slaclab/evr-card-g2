//
//  Command-line driver of TPR configuration
//
#include <stdio.h>
#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <time.h>
#include <stdio.h>

#include "tpr.hh"
#include "tprsh.hh"

#include <string>
#include <vector>
#include <sstream>

//
//  Description : XAPP1251 Xilinx Virtual Cable Server for Linux
//
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/tcp.h>
#include <netinet/in.h> 
#include <pthread.h>

#define MAP_SIZE      0x10000
//#define dsb(scope)    asm volatile("dsb " #scope : : : "memory")
#define dsb(scope) {}

typedef struct {
  uint32_t  length_offset;
  uint32_t  tms_offset;
  uint32_t  tdi_offset;
  uint32_t  tdo_offset;
  uint32_t  ctrl_offset;
} jtag_t;

static int verbose = 0;

static char readBuffer[1024*32];
static int  readLen;

static int sread(int fd, void *target, int len) {
  int wlen = len;
  unsigned char *t = reinterpret_cast<unsigned char*>(target);
  while (len) {
    int r = read(fd, t, len);
    if (r <= 0)
      return r;
    t += r;
    len -= r;
  }
  memcpy(readBuffer+readLen,target,wlen);
  readLen += wlen;
  return 1;
}

int handle_data(int fd, volatile jtag_t* ptr, int ffd) {

  const char xvcInfo[] = "xvcServer_v1.0:2048\n"; 

  char cmd[16];
  unsigned char buffer[8192], result[1024];
  int nr_bytes = 1;

  do {
    memset(cmd, 0, 16);
    readLen  = 0;

    if (sread(fd, cmd, 2) != 1)
      return 1;

    if (memcmp(cmd, "ge", 2) == 0) {
      if (sread(fd, cmd, 6) != 1)
        return 1;
      memcpy(result, xvcInfo, nr_bytes=strlen(xvcInfo));
      if (write(fd, result, strlen(xvcInfo)) != (ssize_t)strlen(xvcInfo)) {
        perror("write");
        return 1;
      }
      if (verbose) {
        printf("%u : Received command: 'getinfo'\n", (int)time(NULL));
        printf("\t Replied with %s\n", xvcInfo);
      }
      break;
    } else if (memcmp(cmd, "se", 2) == 0) {
      if (sread(fd, cmd, 9) != 1)
        return 1;
      memcpy(result, cmd + 5, nr_bytes=4);
      if (write(fd, result, 4) != 4) {
        perror("write");
        return 1;
      }
      if (verbose) {
        printf("%u : Received command: 'settck'\n", (int)time(NULL));
        printf("\t Replied with '%.*s'\n\n", 4, cmd + 5);
      }
      break;
    } else if (memcmp(cmd, "sh", 2) == 0) {
      if (sread(fd, cmd, 4) != 1)
        return 1;
      if (verbose) {
        printf("%u : Received command: 'shift'\n", (int)time(NULL));
      }
    } else {

      fprintf(stderr, "invalid cmd '%s'\n", cmd);
      return 1;
    }

    int len;
    if (sread(fd, &len, 4) != 1) {
      fprintf(stderr, "reading length failed\n");
      return 1;
    }

    nr_bytes = (len + 7) / 8;
    if (size_t(nr_bytes) * 2 > sizeof(buffer)) {
      fprintf(stderr, "buffer size exceeded\n");
      return 1;
    }

    if (sread(fd, buffer, nr_bytes * 2) != 1) {
      fprintf(stderr, "reading data failed\n");
      return 1;
    }
    memset(result, 0, nr_bytes);

    if (verbose) {
      printf("\tNumber of Bits  : %d\n", len);
      printf("\tNumber of Bytes : %d \n", nr_bytes);
      printf("\n");
    }

    int bytesLeft = nr_bytes;
    int bitsLeft = len;
    int byteIndex = 0;
    int tdi, tms, tdo;

    while (bytesLeft > 0) {
      tms = 0;
      tdi = 0;
      tdo = 0;
      if (bytesLeft >= 4) {
        memcpy(&tms, &buffer[byteIndex], 4);
        memcpy(&tdi, &buffer[byteIndex + nr_bytes], 4);

        ptr->length_offset = 32;        
        dsb(st);
        ptr->tms_offset = tms;         
        dsb(st);
        ptr->tdi_offset = tdi;       
        dsb(st);
        ptr->ctrl_offset = 0x01;

        /* Switch this to interrupt in next revision */
        while (ptr->ctrl_offset)
          {
          }

        tdo = ptr->tdo_offset;
        memcpy(&result[byteIndex], &tdo, 4);

        bytesLeft -= 4;
        bitsLeft -= 32;         
        byteIndex += 4;

        if (verbose) {
          printf("LEN : 0x%08x\n", 32);
          printf("TMS : 0x%08x\n", tms);
          printf("TDI : 0x%08x\n", tdi);
          printf("TDO : 0x%08x\n", tdo);
        }

      } else {
        memcpy(&tms, &buffer[byteIndex], bytesLeft);
        memcpy(&tdi, &buffer[byteIndex + nr_bytes], bytesLeft);
          
        ptr->length_offset = bitsLeft;        
        dsb(st);
        ptr->tms_offset = tms;         
        dsb(st);
        ptr->tdi_offset = tdi;       
        dsb(st);
        ptr->ctrl_offset = 0x01;
        /* Switch this to interrupt in next revision */
        while (ptr->ctrl_offset)
          {
          }

        tdo = ptr->tdo_offset;
          
        memcpy(&result[byteIndex], &tdo, bytesLeft);

        if (verbose) {
          printf("LEN : 0x%08x\n", bitsLeft);
          printf("TMS : 0x%08x\n", tms);
          printf("TDI : 0x%08x\n", tdi);
          printf("TDO : 0x%08x\n", tdo);
        }
        break;
      }
    }
    if (write(fd, result, nr_bytes) != nr_bytes) {
      perror("write");
      return 1;
    }

    //  Record read
    if (readLen && ffd>=0) {
      if (verbose)
        printf("Writing request %d bytes %2.2s\n",
               readLen, readBuffer);
      write(ffd, &readLen, 4);
      write(ffd, readBuffer, readLen);
      readLen = 0;
    }
    //  Record write
    if (nr_bytes && ffd>=0) {
      if (verbose)
        printf("Writing response %d bytes\n", nr_bytes);
      int nrb = -nr_bytes;
      write(ffd, &nrb, 4);
      write(ffd, result, nr_bytes);
      nr_bytes = 0;
    }
  } while (1);

  //  Record read
  if (readLen && ffd>=0) {
      if (verbose)
          printf("Writing request %d bytes %2.2s\n",
                 readLen, readBuffer);
      write(ffd, &readLen, 4);
      write(ffd, readBuffer, readLen);
      readLen = 0;
  }
  //  Record write
  if (nr_bytes && ffd>=0) {
      if (verbose)
          printf("Writing response %d bytes\n", nr_bytes);
      int nrb = -nr_bytes;
      write(ffd, &nrb, 4);
      write(ffd, result, nr_bytes);
      nr_bytes = 0;
  }

  /* Note: Need to fix JTAG state updates, until then no exit is allowed */
  return 0;
}

using namespace Tpr;

extern int optind;

static void usage(const char* p) {
  printf("Usage: %s [options]\n",p);
  printf("Options: -d <a..z> : /dev/tpr<arg>[0..a]\n");
  printf("         -p : port\n");
  printf("         -P : path\n");
  printf("         -v : verbose\n");
  printf("Input  for replay requests is tprxvc.in\n");
  printf("Output for replay requests is tprxvc.out\n");
  printf("Input  for replay response is tprxvc.out\n");
}

int main(int argc, char** argv) {

  extern char* optarg;
  char tprid='a';
  int port = 2542;
  struct sockaddr_in address;
  int s;
  const char* path = 0;
  unsigned addr = INADDR_ANY;
  
  int c;
  bool lUsage  = false;
  
  while ( (c=getopt( argc, argv, "a:d:p:P:hv?")) != EOF ) {
    switch(c) {
    case 'a':
        addr = strtoul(optarg,NULL,0);
        break;
    case 'd':
      tprid  = optarg[0];
      if (strlen(optarg) != 1) {
        printf("%s: option `-r' parsing error\n", argv[0]);
        lUsage = true;
      }
      break;
    case 'p':
      port = strtoul(optarg,NULL,0);
      break;
    case 'P': path = optarg; break;
    case 'v':
      verbose = true;
      break;
    case 'h':
      usage(argv[0]);
      exit(0);
    case '?':
    default:
      lUsage = true;
      break;
    }
  }

  if (optind < argc) {
    printf("%s: invalid argument -- %s\n",argv[0], argv[optind]);
    lUsage = true;
  }

  if (lUsage) {
    usage(argv[0]);
    exit(1);
  }

  char dev[16];
  sprintf(dev,"/dev/tpr%c",tprid);
  printf("Using tpr %s\n",dev);

  int fd = open(dev, O_RDWR);
  if (fd<0) {
    perror("Could not open");
    return -1;
  }

  void* ptr = mmap(0, sizeof(TprReg), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
  if (ptr == MAP_FAILED) {
    perror("Failed to map");
    return -2;
  }

  Tpr::TprReg& reg = *reinterpret_cast<Tpr::TprReg*>(ptr);
  printf("BuildStamp: %s\n", reg.version.buildStamp().c_str());

  volatile jtag_t* jptr = (volatile jtag_t*)&reg.debug;

  s = socket(AF_INET, SOCK_STREAM, 0);
               
  if (s < 0) {
    perror("socket");
    return 1;
  }
  
  unsigned i = 1;
  setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &i, sizeof i);

  address.sin_addr.s_addr = addr;
  address.sin_port = htons(port);
  address.sin_family = AF_INET;

  if (bind(s, (struct sockaddr*) &address, sizeof(address)) < 0) {
    perror("bind");
    return 1;
  }

  printf("Listening...\n");
  if (listen(s, 5) < 0) {
    perror("listen");
    return 1;
  }

  fd_set conn;
  int maxfd = 0;

  FD_ZERO(&conn);
  FD_SET(s, &conn);

  maxfd = s;

  int ffd = -1;
  if (path) {
      ffd = open(path,O_WRONLY | O_CREAT);
      if (ffd < 0) {
          perror("open");
          return 1;
      }
      printf("Opened %s on fd %d\n", path,ffd);
  }

  while (1) {
    fd_set read = conn, except = conn;
    int fd;

    if (select(maxfd + 1, &read, 0, &except, 0) < 0) {
      perror("select");
      break;
    }

    for (fd = 0; fd <= maxfd; ++fd) {
      if (FD_ISSET(fd, &read)) {
        if (fd == s) {
          int newfd;
          socklen_t nsize = sizeof(address);

	  newfd = accept(s, (struct sockaddr*) &address, &nsize);

          //               if (verbose)
          printf("connection accepted - fd %d\n", newfd);
          if (newfd < 0) {
            perror("accept");
          } else {
            printf("setting TCP_NODELAY to 1\n");
            int flag = 1;
            int optResult = setsockopt(newfd,
                                       IPPROTO_TCP,
                                       TCP_NODELAY,
                                       (char *)&flag,
                                       sizeof(int));
            if (optResult < 0)
              perror("TCP_NODELAY error");
            if (newfd > maxfd) {
              maxfd = newfd;
            }
            FD_SET(newfd, &conn);
          }
        }
        else if (handle_data(fd,jptr,ffd)) {

          if (verbose)
            printf("connection closed - fd %d\n", fd);
          close(fd);
          FD_CLR(fd, &conn);
        }
      }
      else if (FD_ISSET(fd, &except)) {
        if (verbose)
          printf("connection aborted - fd %d\n", fd);
        close(fd);
        FD_CLR(fd, &conn);
        if (fd == s)
          break;
      }
    }
  }
  munmap((void *) ptr, MAP_SIZE);
  return 0;
}

