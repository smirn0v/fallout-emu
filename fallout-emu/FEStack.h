//
//  FEStack.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#ifndef __fallout_emu__FEStack__
#define __fallout_emu__FEStack__

#include "FECommonTypes.h"
#include <inttypes.h>

typedef struct FEMemoryMap FEMemoryMap;
typedef struct FEMemoryMapBlock FEMemoryMapBlock;
typedef struct FEThreadContext FEThreadContext;

typedef struct FEStack {
    FEMemoryMap *memoryMap;
    FEMemoryMapBlock *stackBlock;
    FEThreadContext* threadContext;
    uint32_t size;
    uint32_t start;
    uint32_t base;
} FEStack;

FEStack *fe_stack_create(uint32_t size, FEMemoryMap *memory, FEThreadContext *threadContext);
void fe_stack_release(FEStack* stack);

void fe_stack_push32(FEStack *stack, uint32_t value);
uint32_t fe_stack_pop32(FEStack *stack);

void fe_stack_push16(FEStack *stack, uint16_t value);
uint16_t fe_stack_pop16(FEStack *stack);

void fe_stack_push(FEStack *stack, uint32_t value, FEBitWidth bitWidth);
uint32_t fe_stack_pop(FEStack *stack, FEBitWidth bitWidth);

#endif
