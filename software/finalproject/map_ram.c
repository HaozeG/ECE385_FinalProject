#include "map_ram.h"
#include <alt_types.h>

void setMAP(BYTE ADDR, BYTE TILE_INDEX) {
    map_ram_ctrl->DATA[ADDR] = TILE_INDEX;
}

void clearMAP() {
	for (int i = 0; i<(ROWS*COLUMNS); i++)
	{
		map_ram_ctrl->DATA[i] = 0x0000;
	}
}
