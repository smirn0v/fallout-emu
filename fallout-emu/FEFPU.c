//
//  FEFPU.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include <assert.h>
#include <stdlib.h>

#include "FEFPU.h"

FEFPU *fe_fpu_create() {
    FEFPU *fpu = malloc(sizeof(FEFPU));
    assert(fpu);
    return fpu;
}

void fe_fpu_release(FEFPU *fpu) {
    assert(fpu);
    if(fpu) {
        free(fpu);
    }
}

uint8_t fe_fpu_top(FEFPU *fpu) {
    return (fpu->statusWord >> 11)&7;
}

uint8_t fe_fpu_flag(FEFPU *fpu, FEFPUFlag flag) {
    return (fpu->statusWord >> flag)&1;
}

void fe_fpu_setFlag(FEFPU *fpu, FEFPUFlag flag) {
    fpu->statusWord = fpu->statusWord | (1<<flag);
}

void fe_fpu_clearFlag(FEFPU *fpu, FEFPUFlag flag) {
    fpu->statusWord = fpu->statusWord & (~(1<<flag));
}

void fe_fpu_fninit(FEFPU *fpu) {
    /*
     FPUControlWord = 0x37F;
     FPUStatusWord = 0;
     FPUTagWord = 0xFFFF;
     FPUDataPointer = 0;
     FPUInstructionPointer = 0;
     FPULastInstructionOpcode = 0;
     */
    
    fpu->controlWord = 0x37f;
    fpu->statusWord = 0;
    fpu->tagWord = 0xffff;
    fpu->instructionPointerOffset = 0;
    fpu->instructionPointerSelector = 0;
    fpu->operandPointerOffset = 0;
    fpu->operandPointerSelector = 0;
    
    //xxx what is data pointer ?
}

void fe_fpu_decrementTop(FEFPU *fpu) {
    uint8_t top = fe_fpu_top(fpu);
    if(top == 0) {
        top = 7;
    } else {
        assert(top > 0);
        fe_fpu_setTag(fpu, kST0, kEmpty);
        top--;
    }
    fpu->statusWord = fpu->statusWord & (~(7<<11));
    fpu->statusWord = fpu->statusWord | ((top & 7) << 11);
}

void fe_fpu_incrementTop(FEFPU *fpu) {
    uint8_t top = fe_fpu_top(fpu);
    top++;
    if(top > 7) {
        // XXX overflow/underflow
        top -= 8;
    }
    fpu->statusWord = fpu->statusWord & (~(7<<11));
    fpu->statusWord = fpu->statusWord | ((top & 7) << 11);
}

FEFPUTag fe_fpu_tag(FEFPU *fpu, FEFPURegisterName registerName) {
    return (FEFPUTag)(fpu->tagWord >> (2*registerName));
}

void fe_fpu_setTag(FEFPU *fpu, FEFPURegisterName registerName, FEFPUTag tag) {
    fpu->tagWord = fpu->tagWord & ~(3<<(2*registerName));
    fpu->tagWord = fpu->tagWord | (tag << (2*registerName));
}

long double fe_fpu_register(FEFPU *fpu, FEFPURegisterName registerName) {
    uint8_t offset = registerName + fe_fpu_top(fpu);
    if(offset > 7) {
        offset -= 8;
    }
    
    return fpu->data[offset];
}

void fe_fpu_setRegister(FEFPU *fpu, FEFPURegisterName registerName, long double value) {
    uint8_t offset = registerName + fe_fpu_top(fpu);
    if(offset > 7) {
        offset -= 8;
    }
    fe_fpu_setTag(fpu, (FEFPURegisterName)offset, kValid);
    
    fpu->data[offset] = value;
}