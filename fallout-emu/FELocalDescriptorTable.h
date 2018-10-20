//
//  FELocalDescriptorTable.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 14/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#ifndef __fallout_emu__FELocalDescriptorTable__
#define __fallout_emu__FELocalDescriptorTable__

#include <inttypes.h>

// OVERsimplified version of LDT
typedef struct FELocalDescriptorTable {
    uint16_t index;
    uint32_t ldt_address[65535];
    uint32_t ldt_size[65535];
} FELocalDescriptorTable;

FELocalDescriptorTable *fe_ldt_create();
void fe_ldt_release(FELocalDescriptorTable *ldt);

uint16_t fe_ldt_createLDWithAddress(FELocalDescriptorTable *ldt, uint32_t address, uint32_t size);
void fe_ldt_releaseLDAtIndex(FELocalDescriptorTable *ldt, uint16_t index);

uint32_t fe_ldt_addressWithSelector(FELocalDescriptorTable *ldt, uint16_t selector);

#endif