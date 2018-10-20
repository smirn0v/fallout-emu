//
//  FEThreadContext.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include <assert.h>
#include <stdlib.h>

#include "FEThreadContext.h"
#include "FEMemoryMap.h"
#include "FEStack.h"
#include "FEFPU.h"
#include "cutils.h"

#include <string.h>


FEThreadContext *fe_threadContext_create(FEMemoryMap *memoryMap, uint32_t stack_size) {
    assert(memoryMap);
    
    if(!memoryMap) {
        return 0;
    }
    
    FEThreadContext *threadContext = malloc(sizeof(FEThreadContext));
    
    assert(threadContext);
    
    if(!threadContext) {
        return 0;
    }
    
    memset(&threadContext->cpuFlags,0, sizeof(threadContext->cpuFlags));
    void *regMap[] = {
        &threadContext->eax, &threadContext->eax, &threadContext->eax, (uint8_t*)(&threadContext->eax)+1,
        &threadContext->ebx, &threadContext->ebx, &threadContext->ebx, (uint8_t*)(&threadContext->ebx)+1,
        &threadContext->ecx, &threadContext->ecx, &threadContext->ecx, (uint8_t*)(&threadContext->ecx)+1,
        &threadContext->edx, &threadContext->edx, &threadContext->edx, (uint8_t*)(&threadContext->edx)+1,
        &threadContext->esi, &threadContext->esi,
        &threadContext->edi, &threadContext->edi,
        &threadContext->ebp, &threadContext->ebp,
        &threadContext->esp, &threadContext->esp,
        &threadContext->eip, &threadContext->eip,
        &threadContext->cs, &threadContext->ds, &threadContext->es, &threadContext->fs, &threadContext->gs, &threadContext->ss
    };
    
    memcpy(threadContext->regMap, regMap, sizeof(threadContext->regMap));
    
    threadContext->memoryMap = memoryMap;
    threadContext->threadId = 1;
    
    threadContext->fpu = fe_fpu_create();
    
    assert(threadContext->fpu);
    
    if(!threadContext->fpu) {
        free(threadContext);
        return 0;
    }
    
    threadContext->stack = fe_stack_create(8*1024, memoryMap, threadContext);
    
    assert(threadContext->stack);
    
    if(!threadContext->stack) {
        fe_fpu_release(threadContext->fpu);
        free(threadContext);
        return 0;
    }
    
    threadContext->TIBAddress = fe_memoryMap_malloc(threadContext->memoryMap, 3*1024, kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write, ".TIB");
    
    /*
     FS:[0x00]	4	Win9x and NT	Current Structured Exception Handling (SEH) frame
     FS:[0x04]	4	Win9x and NT	Stack Base / Bottom of stack (high address)
     FS:[0x08]	4	Win9x and NT	Stack Limit / Ceiling of stack (low address)
     FS:[0x20]	4	NT	Process ID (in some windows distributions this field is used as 'DebugContext')
     FS:[0x24]	4	NT	Current thread ID
     
     */
    // zeroing SEH frame. No idea how to set up this thing properly.
    fe_memoryMap_setValue32(threadContext->memoryMap,threadContext->TIBAddress,0);
    // stack base
    fe_memoryMap_setValue32(threadContext->memoryMap, threadContext->TIBAddress + 0x4, threadContext->stack->base);
    // stack limit
    fe_memoryMap_setValue32(threadContext->memoryMap, threadContext->TIBAddress + 0x8, threadContext->stack->start);
    // process ID
    fe_memoryMap_setValue32(threadContext->memoryMap, threadContext->TIBAddress + 0x20, 0);
    // thread ID
    fe_memoryMap_setValue32(threadContext->memoryMap, threadContext->TIBAddress + 0x24, threadContext->threadId);

    return threadContext;
}

void fe_threadContext_release(FEThreadContext *threadContext) {
    assert(threadContext);
    if(threadContext) {
        fe_stack_release(threadContext->stack);
        fe_fpu_release(threadContext->fpu);
        free(threadContext);
    }
}

inline void fe_threadContext_setRegister32(FEThreadContext *threadContext, FERegisterName name, uint32_t value) {
    *((uint32_t*)threadContext->regMap[name]) = value;
}

inline uint32_t fe_threadContext_register32(FEThreadContext *threadContext, FERegisterName name) {
    return *((uint32_t*)threadContext->regMap[name]);
}

void fe_threadContext_setRegister16(FEThreadContext *threadContext, FERegisterName name, uint16_t value) {
    *((uint16_t*)threadContext->regMap[name]) = value;
}

uint16_t fe_threadContext_register16(FEThreadContext *threadContext, FERegisterName name) {
    return *((uint16_t*)threadContext->regMap[name]);
}

void fe_threadContext_setRegister8(FEThreadContext *threadContext, FERegisterName name, uint8_t value) {
    *((uint8_t*)threadContext->regMap[name]) = value;
}

uint8_t fe_threadContext_register8(FEThreadContext *threadContext, FERegisterName name) {
    return *((uint8_t*)threadContext->regMap[name]);
}

void fe_threadContext_setRegister(FEThreadContext *threadContext, FERegisterName name, uint32_t value, FEBitWidth bitWidth) {
    switch (bitWidth) {
        case k8bit:
            fe_threadContext_setRegister8(threadContext, name, value);
            break;
        case k16bit:
            fe_threadContext_setRegister16(threadContext, name, value);
            break;
        case k32bit:
            fe_threadContext_setRegister32(threadContext, name, value);
            break;
        default:
            assert(0);
            break;
    }
}

uint32_t fe_threadContext_register(FEThreadContext *threadContext, FERegisterName name, FEBitWidth bitWidth) {
    switch (bitWidth) {
        case k8bit:
            return fe_threadContext_register8(threadContext, name);
            break;
        case k16bit:
            return fe_threadContext_register16(threadContext, name);
            break;
        case k32bit:
            return fe_threadContext_register32(threadContext, name);
            break;
        default:
            assert(0);
            break;
    }
}

#define ALU_32bit_2arg_op(PREFIX,OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %4\n"\
"popfw\n"\
"mov %3,%%edx\n"\
"mov %2,%%eax\n"\
OP" %%edx,%%eax\n"\
"pushfw\n"\
"mov %%eax,%1\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1), "g"(arg2), "0"(flagsVector)\
: "%eax","%edx");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_16bit_2arg_op(PREFIX,OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %4\n"\
"popfw\n"\
"mov %3,%%dx\n"\
"mov %2,%%ax\n"\
OP" %%dx,%%ax\n"\
"pushfw\n"\
"mov %%ax,%1\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1), "g"(arg2), "0"(flagsVector)\
: "%eax", "%edx");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_8bit_2arg_op(PREFIX,OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %4\n"\
"popfw\n"\
OP" %3,%2\n"\
"pushfw\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1), "g"(arg2), "0"(flagsVector)\
: "%eax");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_IMP_2arg_op(OP) \
uint32_t fe_threadContext_##OP##32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2) { ALU_32bit_2arg_op("",#OP); return arg1; } \
uint16_t fe_threadContext_##OP##16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2) { ALU_16bit_2arg_op("",#OP); return arg1; } \
uint8_t  fe_threadContext_##OP##8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2) { ALU_8bit_2arg_op("",#OP); return arg1; } \
uint32_t fe_threadContext_##OP(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth) { \
switch(bitWidth) { \
case k8bit:\
return fe_threadContext_##OP##8(threadContext, arg1, arg2);\
break;\
case k16bit:\
return fe_threadContext_##OP##16(threadContext, arg1, arg2);\
break;\
case k32bit:\
return fe_threadContext_##OP##32(threadContext, arg1, arg2);\
break;\
default:\
assert(0);\
}\
}

ALU_IMP_2arg_op(sub);
ALU_IMP_2arg_op(add);
ALU_IMP_2arg_op(adc);
ALU_IMP_2arg_op(sbb);
ALU_IMP_2arg_op(and);
ALU_IMP_2arg_op(xor);
ALU_IMP_2arg_op(or);
ALU_IMP_2arg_op(test);


#define ALU_32bit_2arg_cl_based_op(OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %4\n"\
"popfw\n"\
"mov %3, %%ecx\n"\
OP"l %%cl,%1\n"\
"pushfw\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1), "g"(arg2), "0"(flagsVector)\
: "%rax", "%rcx");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_16bit_2arg_cl_based_op(OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %4\n"\
"popfw\n"\
"mov %3, %%cx\n"\
OP"w %%cl,%1\n"\
"pushfw\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1), "g"(arg2), "0"(flagsVector)\
: "%rax", "%rcx");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_8bit_2arg_cl_based_op(OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %4\n"\
"popfw\n"\
"mov %3, %%cl\n"\
OP"b %%cl,%1\n"\
"pushfw\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1), "g"(arg2),"0"(flagsVector)\
: "%rax", "%rcx");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_IMP_2arg_cl_based_op(OP) \
uint32_t fe_threadContext_##OP##32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2) { ALU_32bit_2arg_cl_based_op(#OP); return arg1; } \
uint16_t fe_threadContext_##OP##16(FEThreadContext *threadContext, uint16_t arg1, uint16_t arg2) { ALU_16bit_2arg_cl_based_op(#OP); return arg1; } \
uint8_t  fe_threadContext_##OP##8(FEThreadContext *threadContext, uint8_t arg1, uint8_t arg2) { ALU_8bit_2arg_cl_based_op(#OP); return arg1; } \
uint32_t fe_threadContext_##OP(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth) { \
switch(bitWidth) { \
case k8bit:\
return fe_threadContext_##OP##8(threadContext, arg1, arg2);\
break;\
case k16bit:\
return fe_threadContext_##OP##16(threadContext, arg1, arg2);\
break;\
case k32bit:\
return fe_threadContext_##OP##32(threadContext, arg1, arg2);\
break;\
default:\
assert(0);\
}\
}

ALU_IMP_2arg_cl_based_op(shl);
ALU_IMP_2arg_cl_based_op(shr);
ALU_IMP_2arg_cl_based_op(sar);
ALU_IMP_2arg_cl_based_op(rol);
ALU_IMP_2arg_cl_based_op(ror);
ALU_IMP_2arg_cl_based_op(rcl);
ALU_IMP_2arg_cl_based_op(rcr);

#define ALU_32bit_1arg_op(OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %3\n"\
"popfw\n"\
OP"l %1\n"\
"pushfw\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1),"0"(flagsVector)\
: "%rax", "%rcx");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_16bit_1arg_op(OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %3\n"\
"popfw\n"\
OP"w %1\n"\
"pushfw\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1),"0"(flagsVector)\
: "%rax", "%rcx");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_8bit_1arg_op(OP) {\
int16_t flagsVector = fe_cpuflags_16(threadContext->cpuFlags);\
asm(\
"pushw %3\n"\
"popfw\n"\
OP"b %1\n"\
"pushfw\n"\
"popw %%ax\n"\
"mov %%ax,%0\n"\
:"=r"(flagsVector),"=r"(arg1)\
:"1"(arg1),"0"(flagsVector)\
: "%rax", "%rcx");\
fe_cpuflags_fillFrom16it(&threadContext->cpuFlags, flagsVector);\
}

#define ALU_IMP_1arg_op(OP) \
uint32_t fe_threadContext_##OP##32(FEThreadContext *threadContext, uint32_t arg1) { ALU_32bit_1arg_op(#OP); return arg1; } \
uint16_t fe_threadContext_##OP##16(FEThreadContext *threadContext, uint16_t arg1) { ALU_16bit_1arg_op(#OP); return arg1; } \
uint8_t fe_threadContext_##OP##8(FEThreadContext *threadContext, uint8_t arg1) { ALU_8bit_1arg_op(#OP); return arg1; } \
uint32_t fe_threadContext_##OP(FEThreadContext *threadContext, uint32_t arg1, FEBitWidth bitWidth) { \
switch(bitWidth) { \
case k8bit:\
return fe_threadContext_##OP##8(threadContext, arg1);\
break;\
case k16bit:\
return fe_threadContext_##OP##16(threadContext, arg1);\
break;\
case k32bit:\
return fe_threadContext_##OP##32(threadContext, arg1);\
break;\
default:\
assert(0);\
}\
}

ALU_IMP_1arg_op(dec)
ALU_IMP_1arg_op(inc)
ALU_IMP_1arg_op(not)
ALU_IMP_1arg_op(neg)

uint64_t fe_threadContext_imul32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth) {
    int64_t sArg1 = beu_sign_extend(arg1, bitWidth);
    int64_t sArg2 = beu_sign_extend(arg2, bitWidth);
    
    int64_t result = sArg1 * sArg2;
    // The CF and OF flags are set when the signed integer value of the intermediate product differs from the sign extended operand-size-truncated product, otherwise the CF and OF flags are cleared.
    char flag = 0;
    char sign = 0;
    switch(bitWidth) {
        case k8bit: {
            int8_t truncated = (int8_t)result;
            flag = truncated != result;
            sign = (truncated>>7)&1;
        }
            break;
        case k16bit: {
            int16_t truncated = (int16_t)result;
            flag = truncated != result;
            sign = (truncated>>15)&1;
        }
            break;
        case k32bit: {
            int32_t truncated = (int32_t)result;
            flag = truncated != result;
            sign = (truncated>>31)&1;
        }
            break;
        default:
            assert(0);
    }
    fe_cpuflags_fillParityFromByte(&threadContext->cpuFlags, result&0xff);
    threadContext->cpuFlags.CF = flag;
    threadContext->cpuFlags.OF = flag;
    threadContext->cpuFlags.SF = sign;
    return result;

}


uint64_t fe_threadContext_mul32(FEThreadContext *threadContext, uint32_t arg1, uint32_t arg2, FEBitWidth bitWidth) {
    /*
     The result is stored in register AX, register pair DX:AX, or register pair EDX:EAX (depending on the operand size), with the high-order bits of the product contained in register AH, DX, or EDX, respectively. If the high-order bits of the product are 0, the CF and OF flags are cleared; otherwise, the flags are set.
     */
    uint64_t uArg1 = 0;
    uint64_t uArg2 = 0;
    
    uint64_t result;
    char flag = 0;
    char sign = 0;
    switch(bitWidth) {
        case k8bit: {
            uArg1 = (uint8_t)arg1;
            uArg2 = (uint8_t)arg2;
            result = uArg1 * uArg2;
            uint8_t truncated = result;
            flag = ((result>>8)&0xff) != 0;
            sign = (truncated>>7)&1;
        }
            break;
        case k16bit: {
            uArg1 = (uint16_t)arg1;
            uArg2 = (uint16_t)arg2;
            result = uArg1 * uArg2;
            uint16_t truncated = result;
            flag = ((result>>16)&0xffff) !=0;
            sign = (truncated>>15)&1;
        }
            break;
        case k32bit: {
            uArg1 = (uint32_t)arg1;
            uArg2 = (uint32_t)arg2;
            result = uArg1 * uArg2;
            uint32_t truncated = (uint32_t)result;
            flag = ((result>>32)&0xffffffff) != 0;
            sign = (truncated>>31)&1;
        }
            break;
        default:
            assert(0);
    }
    fe_cpuflags_fillParityFromByte(&threadContext->cpuFlags, result&0xff);
    
    threadContext->cpuFlags.CF = flag;
    threadContext->cpuFlags.OF = flag;
    threadContext->cpuFlags.SF = sign;
    
    return result;
}

int64_t fe_threadContext_idiv32(FEThreadContext *threadContext, int64_t arg1, int64_t arg2, FEBitWidth bitWidth, int64_t *remainder) {
    assert(remainder);
    
    if(!remainder) {
        return 0;
    }
    
    if(arg2 == 0) {
        //devide by zero
        assert(0);
    }
    
    int64_t quotient = arg1/arg2;
    *remainder = (uint64_t)(arg1 % arg2);
    
    switch(bitWidth) {
        case k8bit: {
            //IF (temp > 7FH) or (temp < 80H)
            if(quotient > 0x7f || quotient < -((int16_t)0x80)) {
                //result out of range
                assert(0);
            }
        }
            break;
        case k16bit: {
            if(quotient > 0x7FFF || quotient < -((int32_t)0x8000)) {
                // result out of range
                assert(0);
            }
        }
            break;
        case k32bit: {
            if(quotient > 0x7FFFFFFF || quotient < -((int64_t)0x80000000)) {
                // result out of range
                assert(0);
            }
        }
            break;
        default:
            assert(0);
    }
    
    return quotient;
}

uint64_t fe_threadContext_div32(FEThreadContext *threadContext, uint64_t arg1, uint64_t arg2, FEBitWidth bitWidth, uint64_t *remainder) {
    assert(remainder);
    
    if(!remainder) {
        return 0;
    }
    
    if(arg2 == 0) {
        // devide by zero
        assert(0);
    }
    
    uint64_t quotient = arg1/arg2;
    *remainder = (uint64_t)(arg1 % arg2);
    
    switch(bitWidth) {
        case k8bit: {
            if(quotient > 0xff) {
                // result out of range
                assert(0);
            }
        }
            break;
        case k16bit: {
            if(quotient > 0xffff) {
                // result out of range
                assert(0);
            }
        }
            
            break;
        case k32bit: {
            if(quotient > 0xffffffff) {
                // result out of range
                assert(0);
            }
        }
            
            break;
    }
    
    return quotient;
}
