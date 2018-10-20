//
//  FEmemoryMapBlock.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//
#ifndef __fallout_emu__FEMemoryMapBlock__
#define __fallout_emu__FEMemoryMapBlock__

#import "FEMemoryAccessMode.h"
#include "FEArray.h"
#include <inttypes.h>


typedef struct FEMemoryMapBlock {
    uint32_t virtualAddress;
    uint32_t end;
    uint32_t size;
    char *localAddress;
    uint8_t freeWhenDone;
    char *tag;
    void *context;
} FEMemoryMapBlock;

FEMemoryMapBlock *fe_memoryMapBlock_create(const char *tag);
void fe_memoryMapBlock_release(FEMemoryMapBlock *block);
uint8_t fe_memoryMapBlock_containsVirtualAddress(FEMemoryMapBlock *block, uint32_t address);

FEComparisonResult fe_memoryMapBlock_compare(const void*, const void*);


#endif
