//
//  FEStack.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//


#include "FEThreadContext.h"

#include "FEStack.h"
#include "FEMemoryMap.h"
#include "FEMemoryMapBlock.h"

#include <assert.h>
#include <stdlib.h>


FEStack *fe_stack_create(uint32_t size, FEMemoryMap *memory, FEThreadContext *threadContext) {
    
    assert(size);
    assert(memory);
    assert(threadContext);
    
    FEStack *stack = malloc(sizeof(FEStack));
    
    stack->threadContext = threadContext;
    stack->memoryMap = memory;
    stack->size = size;
    
    stack->start = fe_memoryMap_malloc(memory, size, kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write, ".stack");
    
    stack->base = stack->start + stack->size;
    stack->stackBlock = fe_memoryMap_blockFromVirtualAddress(memory, stack->start);
    
    threadContext->esp = stack->start + size;
    
    return stack;
}

void fe_stack_release(FEStack* stack) {
    assert(stack);
    if(!stack) {
        return;
    }
    
    fe_memoryMap_free(stack->memoryMap, stack->base);
    free(stack);
}

void fe_stack_push32(FEStack *stack, uint32_t value) {
    uint32_t stack_ptr = stack->threadContext->esp;
    stack_ptr -= 4;
    assert(stack_ptr > stack->start && (stack_ptr <= (stack->base-4)));
    
    uint32_t offset = stack_ptr - stack->start;
    *((uint32_t*)(stack->stackBlock->localAddress+offset)) = value;
    
    stack->threadContext->esp = stack_ptr;
}

uint32_t fe_stack_pop32(FEStack *stack) {
    uint32_t stack_ptr = stack->threadContext->esp;
    assert(stack_ptr < stack->base);

    uint32_t result = *((uint32_t*)(stack->stackBlock->localAddress+(stack_ptr-stack->start)));
    
    stack_ptr += 4;
    
    stack->threadContext->esp = stack_ptr;

    return result;
}

void fe_stack_push16(FEStack *stack, uint16_t value) {
    uint32_t stack_ptr = stack->threadContext->esp;
    stack_ptr -= 2;
    assert(stack_ptr > stack->start);
    fe_memoryMap_setValue16(stack->memoryMap, stack_ptr, value);
    
    stack->threadContext->esp = stack_ptr;
}

uint16_t fe_stack_pop16(FEStack *stack) {
    uint32_t stack_ptr = stack->threadContext->esp;
    assert(stack_ptr < stack->base);
    uint16_t result = *((uint16_t*)(stack->stackBlock->localAddress+(stack_ptr-stack->start)));
    stack_ptr += 2;
    stack->threadContext->esp = stack_ptr;
    return result;
}

void fe_stack_push(FEStack *stack, uint32_t value, FEBitWidth bitWidth) {
    switch(bitWidth) {
        case k32bit:
            fe_stack_push32(stack, value);
            break;
        case k16bit:
            fe_stack_push16(stack, value);
            break;
        case k8bit: {
            int8_t origValue = (int8_t)value;
            uint32_t signExtended = (int32_t)origValue;
            fe_stack_push32(stack, signExtended);
        }
            break;
        default:
            assert(0);
    }
}

uint32_t fe_stack_pop(FEStack *stack, FEBitWidth bitWidth) {
    switch(bitWidth) {
        case k32bit:
            return fe_stack_pop32(stack);
            break;
        case k16bit:
            return fe_stack_pop16(stack);
            break;
        default:
            assert(0);
    }
    return 0;
}