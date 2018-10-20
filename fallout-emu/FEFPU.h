//
//  FEFPU.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#ifndef __fallout_emu__FEFPU__
#define __fallout_emu__FEFPU__

#include <inttypes.h>
/*
 16-Bit Protected Mode Format
 Control Word
 Status Word
 Tag Word
 FPU Instruction Pointer Offset
 FPU Instruction Pointer Selector
 FPU Operand Pointer Offset
 FPU Operand Pointer Selector
 */

typedef enum FEFPURegisterName {
    kST0 = 0,
    kST1,
    kST2,
    kST3,
    kST4,
    kST5,
    kST6,
    kST7,
} FEFPURegisterName;


/*
 00 — Valid
 01 — Zero
 10 — Special: invalid (NaN, unsupported), infinity, or denormal
 11 — Empty
 */
typedef enum FEFPUTag {
    kValid = 0,
    kZero  = 1,
    kSpecial = 2,
    kEmpty = 3
} FEFPUTag;

typedef enum FEFPUFlag {
    kC0 = 8,
    kC1 = 9,
    kC2 = 10,
    kC3 = 14
} FEFPUFlag;

typedef struct FEFPU {
    uint16_t controlWord;
    uint16_t statusWord;
    uint16_t tagWord;
    uint32_t instructionPointerOffset;
    uint32_t instructionPointerSelector;
    uint32_t operandPointerOffset;
    uint32_t operandPointerSelector;
    long double data[8];
} FEFPU;

FEFPU *fe_fpu_create();
void fe_fpu_release(FEFPU *fpu);

uint8_t fe_fpu_top(FEFPU *fpu);
uint8_t fe_fpu_flag(FEFPU *fpu, FEFPUFlag flag);
void fe_fpu_setFlag(FEFPU *fpu, FEFPUFlag flag);
void fe_fpu_clearFlag(FEFPU *fpu, FEFPUFlag flag);

void fe_fpu_fninit(FEFPU *fpu);

void fe_fpu_decrementTop(FEFPU *fpu);
void fe_fpu_incrementTop(FEFPU *fpu);

FEFPUTag fe_fpu_tag(FEFPU *fpu, FEFPURegisterName registerName);
void fe_fpu_setTag(FEFPU *fpu, FEFPURegisterName registerName, FEFPUTag tag);

long double fe_fpu_register(FEFPU *fpu, FEFPURegisterName registerName);
void fe_fpu_setRegister(FEFPU *fpu, FEFPURegisterName registerName, long double value);

#endif