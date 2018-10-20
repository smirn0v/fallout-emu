//
//  FEmemoryMapBlock.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include "FEMemoryMapBlock.h"
#include <string.h>
#include <stdlib.h>


FEMemoryMapBlock *fe_memoryMapBlock_create(const char *tag) {
    FEMemoryMapBlock *block = malloc(sizeof(FEMemoryMapBlock));
    if(block == NULL) {
        return NULL;
    }
    
    block->tag = strndup(tag, 256);
    block->context = 0;
    
    if(!block->tag) {
        free(block);
        return NULL;
    }
    
    return block;
}

void fe_memoryMapBlock_release(FEMemoryMapBlock *block) {
    if(block) {
        if(block->freeWhenDone && block->localAddress) {
            free(block->localAddress);
            block->localAddress = NULL;
        }
        
        if(block->tag) {
            free(block->tag);
            block->tag = NULL;
        }
        
        free(block);
    }
}

inline uint8_t fe_memoryMapBlock_containsVirtualAddress(FEMemoryMapBlock *block, uint32_t address) {
    return block->virtualAddress <= address && (block->end > address);
}

FEComparisonResult fe_memoryMapBlock_compare(const void* b1, const void* b2) {
    const FEMemoryMapBlock *block1 = *(FEMemoryMapBlock**)b1;
    const FEMemoryMapBlock *block2 = *(FEMemoryMapBlock**)b2;
    
    if(block1->virtualAddress < block2->virtualAddress) {
        return FEComparisonResult_Ascendent;
    }
    if(block1->virtualAddress > block2->virtualAddress) {
        return FEComparisonResult_Descendent;
    }
    return FEComparisonResult_Same;
}
