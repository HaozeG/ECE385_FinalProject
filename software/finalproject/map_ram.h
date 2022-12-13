#ifndef MAP_RAM_H_
#define MAP_RAM_H_

#define ROWS  16
#define COLUMNS 16

#include <system.h>
#include <alt_types.h>
#include "usb_kb/GenericTypeDefs.h"

struct MAP_RAM_STRUCT {
	alt_u8 DATA [ROWS*COLUMNS];
};

//you may have to change this line depending on your platform designer
static volatile struct MAP_RAM_STRUCT* map_ram_ctrl = AVL_INTERFACE_0_BASE;

void setMAP(BYTE ADDR, BYTE TILE_INDEX);

void clearMAP();

#endif
