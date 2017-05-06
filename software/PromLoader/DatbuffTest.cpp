/*
 * pcimem.c: Simple program to read/write from/to a pci device from userspace.
 *
 *  Copyright (C) 2010, Bill Farrow (bfarrow@beyondelectronics.us)
 *
 *  Based on the devmem2.c code
 *  Copyright (C) 2000, Jan-Derk Bakker (J.D.Bakker@its.tudelft.nl)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <signal.h> 
#include <fcntl.h>
#include <ctype.h>
#include <termios.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <stdint.h>

#define PRINT_ERROR \
	do { \
		fprintf(stderr, "Error at line %d, file %s (%d) [%s]\n", \
		__LINE__, __FILE__, errno, strerror(errno)); exit(1); \
	} while(0)

#define MAP_SIZE 4096UL
#define MAP_MASK (MAP_SIZE - 1)

int main(int argc, char **argv) {
	int fd;
	void *map_base, *virt_addr;
	unsigned long read_result;
	char *filename;
	off_t target;
	int access_type = 'w';

	if(argc < 3) {
		// example: pcimem /sys/bus/pci/devices/0001\:00\:07.0/resource0 0x100 w 0x00
		// argv[0]  [1]                                         [2]   [3] [4]
		fprintf(stderr, "\nUsage:\t%s { sys file } { offset } [ type [ data ] ]\n"
			"\tsys file: sysfs file for the pci resource to act on\n"
			"\toffset  : offset into pci memory region to act upon\n"
			"\ttype    : access operation type : [b]yte, [h]alfword, [w]ord\n"
			"\tdata    : data to be written\n\n",
			argv[0]);
		exit(1);
	}
	filename = argv[1];
	target = strtoul(argv[2], 0, 0);

	if(argc > 3)
		access_type = tolower(argv[3][0]);

    if((fd = open(filename, O_RDWR | O_SYNC)) == -1) PRINT_ERROR;
    printf("%s opened.\n", filename);
    printf("Target offset is 0x%x, page size is %d\n", (unsigned int)target, (int)sysconf(_SC_PAGE_SIZE));
    fflush(stdout);

    /* Map one page */
    printf("mmap(%d, %d, 0x%x, 0x%x, %d, 0x%x)\n", 0, (int)MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (unsigned int)target);
    map_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, target & ~MAP_MASK);
    if(map_base == (void *) -1) PRINT_ERROR;
    // printf("PCI Memory mapped to address 0x%02X.\n", map_base);
    fflush(stdout);

    virt_addr = (void *)((uint64_t)map_base+(target & MAP_MASK));
	
	int i;
	
	if(argc < 4) {
		for(i = 0; i < (int)MAP_SIZE; i += 4) {
			volatile uint32_t val32;
			volatile uint8_t *val8 = (volatile uint8_t *)&val32;
			
			
			if(i % 32 == 0) printf("\n%04X   ", (unsigned int)(target + i));
			
// #define READ_TWICE
			
#ifdef READ_TWICE
         val32 = *((uint32_t*)((uint64_t)virt_addr+i));
#endif
         val32 = *((uint32_t*)((uint64_t)virt_addr+i));
			
			read_result = val8[0];
			printf("%02X", (unsigned int)read_result);
			read_result = val8[1];
			printf("%02X", (unsigned int)read_result);
			read_result = val8[2];
			printf("%02X", (unsigned int)read_result);
			read_result = val8[3];
			printf("%02X", (unsigned int)read_result);
			printf(" ");
		}
		
		fflush(stdout);
	}

	if(munmap(map_base, MAP_SIZE) == -1) PRINT_ERROR;
    close(fd);
    return 0;
}

