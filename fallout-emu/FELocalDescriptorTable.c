//
//  FELocalDescriptorTable.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 14/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include "FELocalDescriptorTable.h"

#include <stdlib.h>
#include <string.h>
#include <assert.h>

FELocalDescriptorTable *fe_ldt_create() {
    FELocalDescriptorTable *ldt = malloc(sizeof(FELocalDescriptorTable));
    assert(ldt);
    if(ldt) {
        ldt->index = 50;
        memset(ldt->ldt_address, 0, sizeof(ldt->ldt_address));
        memset(ldt->ldt_size, 0, sizeof(ldt->ldt_size));
    }
    return ldt;
}

void fe_ldt_release(FELocalDescriptorTable *ldt) {
    assert(ldt);
    if(ldt) {
        free(ldt);
    }
}

uint16_t fe_ldt_createLDWithAddress(FELocalDescriptorTable *ldt, uint32_t address, uint32_t size) {
    assert(ldt);
    if(!ldt || ldt->index==65535) {
        exit(-1);//xxx
    }
    
    ldt->index++;
    
    ldt->ldt_address[ldt->index] = address;
    ldt->ldt_size[ldt->index] = size;
    
    return ldt->index;
    
}
void fe_ldt_releaseLDAtIndex(FELocalDescriptorTable *ldt, uint16_t index) {
    
}

uint32_t fe_ldt_addressWithSelector(FELocalDescriptorTable *ldt, uint16_t selector) {
    assert(ldt);
    if(!ldt) {
        exit(-1);//xxx
    }
    return ldt->ldt_address[selector];
}