//
//  FEThreadContext.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//
#ifndef __fallout_emu__FEThreadContext__
#define __fallout_emu__FEThreadContext__

#include "FECommonTypes.h"
#include "FECPUFlags.h"
#include <inttypes.h>

typedef struct FEMemoryMap FEMemoryMap;
typedef struct FEStack FEStack;
typedef struct FEFPU FEFPU;

typedef enum FERegisterName {
    kEAX, kAX, kAL, kAH, //0  1  2  3
    kEBX, kBX, kBL, kBH, //4  5  6  7
    kECX, kCX, kCL, kCH, //8  9  10 11
    kEDX, kDX, kDL, kDH, //12 13 14 15
    kESI, kSI, //16 17
    kEDI, kDI, //18 19
    kEBP, kBP, //20 21
    kESP, kSP, //22 23
    kEIP, kIP, //24 25
    kCS, kDS, kES, kFS, kGS, kSS
} FERegisterName;

typedef uint32_t FE32Register;
typedef uint16_t FE16Register;


typedef struct FEThreadContext {
    FEMemoryMap *memoryMap;
    FEStack *stack;
    FEFPU *fpu;
    FECPUFlags cpuFlags;
    
    void *regMap[32];
    
    FE32Register eax;
    FE32Register ebx;
    FE32Register ecx;
    FE32Register edx;
    FE32Register esi;
    FE32Register edi;
    FE32Register ebp;
    FE32Register esp;
    FE32Register eip;
    
    FE16Register cs;
    FE16Register ds;
    FE16Register es;
    FE16Register fs;
    FE16Register gs;
    FE16Register ss;
    
    
    
    uint16_t threadId;
    uint32_t TIBAddress;
} FEThreadContext;

FEThreadContext *fe_threadContext_create(FEMemoryMap *memoryMap, uint32_t stack_size);
void fe_threadContext_release(FEThreadContext *threadContext);

void fe_threadContext_setRegister32(FEThreadContext *threadContext, FERegisterName name, uint32_t value);
uint32_t fe_threadContext_register32(FEThreadContext *threadContext, FERegisterName name);

void fe_threadContext_setRegister16(FEThreadContext *threadContext, FERegisterName name, uint16_t value);
uint16_t fe_threadContext_register16(FEThreadContext *threadContext, FERegisterName name);

void fe_threadContext_setRegister8(FEThreadContext *threadContext, FERegisterName name, uint8_t value);
uint8_t fe_threadContext_register8(FEThreadContext *threadContext, FERegisterName name);

void fe_threadContext_setRegister(FEThreadContext *threadContext, FERegisterName name, uint32_t value, FEBitWidth bitWidth);
uint32_t fe_threadContext_register(FEThreadContext *threadContext, FERegisterName name, FEBitWidth bitWidth);

uint32_t fe_threadContext_sub32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_sub16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_sub8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_sub(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_add32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_add16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_add8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_add(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_adc32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_adc16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_adc8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_adc(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_and32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_and16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_and8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_and(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_xor32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_xor16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_xor8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_xor(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_or32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_or16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_or8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_or(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_test32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_test16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_test8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_test(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_shl32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_shl16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_shl8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_shl(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_sbb32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_sbb16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_sbb8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_sbb(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_shr32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_shr16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_shr8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_shr(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_sar32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_sar16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_sar8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_sar(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_rol32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_rol16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_rol8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_rol(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_ror32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_ror16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_ror8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_ror(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_rcl32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_rcl16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_rcl8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_rcl(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_rcr32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2);
uint16_t fe_threadContext_rcr16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2);
uint8_t  fe_threadContext_rcr8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2);
uint32_t fe_threadContext_rcr(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

uint32_t fe_threadContext_dec32(FEThreadContext *threadContext, uint32_t arg1);
uint16_t fe_threadContext_dec16(FEThreadContext *threadContext, uint16_t arg1);
uint8_t  fe_threadContext_dec8(FEThreadContext *threadContext, uint8_t arg1);
uint32_t fe_threadContext_dec(FEThreadContext *threadContext, uint32_t arg1, FEBitWidth bitWidth);

uint32_t fe_threadContext_inc32(FEThreadContext *threadContext, uint32_t arg1);
uint16_t fe_threadContext_inc16(FEThreadContext *threadContext, uint16_t arg1);
uint8_t  fe_threadContext_inc8(FEThreadContext *threadContext, uint8_t arg1);
uint32_t fe_threadContext_inc(FEThreadContext *threadContext, uint32_t arg1, FEBitWidth bitWidth);

uint32_t fe_threadContext_not32(FEThreadContext *threadContext, uint32_t arg1);
uint16_t fe_threadContext_not16(FEThreadContext *threadContext, uint16_t arg1);
uint8_t  fe_threadContext_not8(FEThreadContext *threadContext, uint8_t arg1);
uint32_t fe_threadContext_not(FEThreadContext *threadContext, uint32_t arg1, FEBitWidth bitWidth);

uint32_t fe_threadContext_neg32(FEThreadContext *threadContext, uint32_t arg1);
uint16_t fe_threadContext_neg16(FEThreadContext *threadContext, uint16_t arg1);
uint8_t  fe_threadContext_neg8(FEThreadContext *threadContext, uint8_t arg1);
uint32_t fe_threadContext_neg(FEThreadContext *threadContext, uint32_t arg1, FEBitWidth bitWidth);

uint64_t fe_threadContext_imul32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);
uint64_t fe_threadContext_mul32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth);

int64_t fe_threadContext_idiv32(FEThreadContext *threadContext, int64_t arg1, int64_t arg2, FEBitWidth bitWidth, int64_t *remainder);
uint64_t fe_threadContext_div32(FEThreadContext *threadContext, uint64_t arg1, uint64_t arg2, FEBitWidth bitWidth, uint64_t *remainder);

#endif
