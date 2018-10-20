//
//  beaengine_utils.c
//  fallout-emu
//
//  Created by Alexander Smirnov on 25/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "beaengine_utils.h"

#include "FEThreadContext.h"
#import "FEProcess.h"
#include "FELocalDescriptorTable.h"
#include "FEMemoryMap.h"
#include "FEMemoryMapBlock.h"
#include "cutils.h"

#include "beaengine/BeaEngine.h"


void beu_update_disasm_from_context(DISASM **disasm_op, int *len, uint8_t *modrm, FEProcessContext *process) {

    static DISASM dummyOp = {0};
    
    uint32_t eip = process->currentThread->eip;
    
    FEMemoryMapBlock *memoryMapBlock = fe_memoryMap_blockFromVirtualAddress(process->memory, eip);

    assert(memoryMapBlock);
    
    uint8_t not_writable = !!!(fe_memoryMap_accessModeAtAddress(process->memory, eip)&kFEMemoryAccessMode_Write);
    
    if(!memoryMapBlock->context && not_writable) {
        memoryMapBlock->context = malloc(sizeof(DisasmContext));
        assert(memoryMapBlock->context);
        DisasmContext *context = memoryMapBlock->context;
        uint32_t size_of_indexes = memoryMapBlock->size*sizeof(int32_t);
        context->indexes =  malloc(size_of_indexes);
        assert(context->indexes);
        context->disasmed = fe_array_create(sizeof(DISASM), 512, 1);
        context->lens = fe_array_create(sizeof(int), 512, 1);
        memset(context->indexes,-1,size_of_indexes);
    }
    
    DisasmContext *context = memoryMapBlock->context;
                
    char *reip = memoryMapBlock->localAddress + (eip - memoryMapBlock->virtualAddress);

    *modrm = *(reip+1);
    
    if(not_writable) {
        uint32_t index_at_indexes = (eip - memoryMapBlock->virtualAddress);
        int32_t index_at_disasmed = context->indexes[index_at_indexes];
        if(index_at_disasmed == -1) {

            context->indexes[index_at_indexes] = context->disasmed->size;
            
            if(context->disasmed->size >= context->disasmed->capacity) {
                fe_array_append(context->disasmed, &dummyOp);
            } else {
                context->disasmed->size++;
            }
            
            DISASM *op = fe_array_index_addr(context->disasmed, context->indexes[index_at_indexes]);

            op->Archi = 32;
            op->EIP = (UIntPtr)(reip);
            op->VirtualAddr = eip;
            
            *len = Disasm(op);

            if(*len == UNKNOWN_OPCODE) {
                fprintf(stderr, "fail\n");
                exit(-1);
            }
            
            fe_array_append(context->lens, len);
        
            *disasm_op = op;

        } else {
            *disasm_op = fe_array_index_addr(context->disasmed, index_at_disasmed);
            *len = fe_array_index(context->lens, int, index_at_disasmed);
        }
    } else {
        *disasm_op = &dummyOp;
        memset(*disasm_op,0,sizeof(DISASM));
        (*disasm_op)->Archi = 32;
        (*disasm_op)->EIP = (UIntPtr)(reip);
        (*disasm_op)->VirtualAddr = eip;
        
        *len = Disasm(*disasm_op);
        
        if(*len == UNKNOWN_OPCODE) {
            fprintf(stderr, "fail\n");
            exit(-1);
        }
    }
}

uint32_t beu_load_arg_value(ARGTYPE * arg, uint32_t immediat, FEProcessContext *process) {
    FEBitWidth bitWidth = (FEBitWidth)arg->ArgSize;
    
    if(arg->ArgType & REGISTER_TYPE) {
        if(arg->ArgType & GENERAL_REG) {
            FERegisterName regName = beu_register_from_argtype(arg->ArgType, arg->ArgPosition,  bitWidth);
            return fe_threadContext_register(process->currentThread, regName, bitWidth);
        } else if (arg->ArgType & SEGMENT_REG) {
            FERegisterName regName = beu_seg_register_from_argtype(arg->ArgType);
            return fe_threadContext_register(process->currentThread, regName, bitWidth);
        } else {
            assert(false);
        }
    } else if(arg->ArgType & MEMORY_TYPE) {
        return beu_load(arg, process, bitWidth);
    } else if(arg->ArgType & CONSTANT_TYPE) {
        return (uint32_t)beu_sign_extend(immediat, bitWidth);
    }
    
    assert(false);
    return 0;
}

void beu_store_value_in_arg(ARGTYPE * arg, uint32_t value, FEProcessContext *process) {
    FEBitWidth bitWidth = (FEBitWidth)arg->ArgSize;
    
    if(arg->ArgType & REGISTER_TYPE) {
        if(arg->ArgType & GENERAL_REG) {
            FERegisterName regName = beu_register_from_argtype(arg->ArgType, arg->ArgPosition,  bitWidth);
            fe_threadContext_setRegister(process->currentThread, regName, value, bitWidth);
        } else if (arg->ArgType & SEGMENT_REG) {
            FERegisterName regName = beu_seg_register_from_argtype(arg->ArgType);
            fe_threadContext_setRegister(process->currentThread, regName, value, bitWidth);
        } else {
            assert(false);
        }
    } else if(arg->ArgType & MEMORY_TYPE) {
        beu_store(value, arg, process, bitWidth);
    } else {
        assert(false);
    }
}

FERegisterName beu_register32_from_argtype(Int32 argtype, Int32 argposition) {
    assert(argposition == 0);

    if(argtype & REG0) return kEAX;
    if(argtype & REG1) return kECX;
    if(argtype & REG2) return kEDX;
    if(argtype & REG3) return kEBX;
    if(argtype & REG4) return kESP;
    if(argtype & REG5) return kEBP;
    if(argtype & REG6) return kESI;
    if(argtype & REG7) return kEDI;
    
    assert(false);
    @throw [NSException new];
}

FERegisterName beu_register16_from_argtype(Int32 argtype, Int32 argposition) {
    assert(argposition == 0);
    if(argtype & REG0) return kAX;
    if(argtype & REG1) return kCX;
    if(argtype & REG2) return kDX;
    if(argtype & REG3) return kBX;
    if(argtype & REG4) return kSP;
    if(argtype & REG5) return kBP;
    if(argtype & REG6) return kSI;
    if(argtype & REG7) return kDI;
    
    assert(false);
    @throw [NSException new];
}
//REG0 = 0x1,  ( RAX / MM0 / ST0 / XMM0 / CR0 / DR0 / GDTR / ES )
//REG1 = 0x2,  ( RCX / MM1 / ST1 / XMM1 / CR1 / DR1 / LDTR / CS )
//REG2 = 0x4,  ( RDX / MM2 / ST2 / XMM2 / CR2 / DR2 / IDTR / SS )
//REG3 = 0x8,  ( RBX / MM3 / ST3 / XMM3 / CR3 / DR3 / TR   / DS )
//REG4 = 0x10, ( RSP / MM4 / ST4 / XMM4 / CR4 / DR4 / ---- / FS )
//REG5 = 0x20, ( RBP / MM5 / ST5 / XMM5 / CR5 / DR5 / ---- / GS )
FERegisterName beu_seg_register_from_argtype(Int32 argtype) {
    if(argtype & REG0) return kES;
    if(argtype & REG1) return kCS;
    if(argtype & REG2) return kSS;
    if(argtype & REG3) return kDS;
    if(argtype & REG4) return kFS;
    if(argtype & REG5) return kGS;
    
    assert(false);
    @throw [NSException new];
}

FEFPURegisterName beu_fpu_register_from_argtype(Int32 argtype) {
    assert(argtype & FPU_REG);
    
    if(argtype & REG0) return kST0;
    if(argtype & REG1) return kST1;
    if(argtype & REG2) return kST2;
    if(argtype & REG3) return kST3;
    if(argtype & REG4) return kST4;
    if(argtype & REG5) return kST5;
    if(argtype & REG6) return kST6;
    if(argtype & REG7) return kST7;
    
    assert(false);
    @throw [NSException new];
}

FERegisterName beu_seg_register_from_number(uint8_t number) {
    /*
     #define ESReg 1
     #define DSReg 2
     #define FSReg 3
     #define GSReg 4
     #define CSReg 5
     #define SSReg 6
     */
    static uint8_t seg_regs[7] = {0,kES,kDS,kFS,kGS,kCS,kSS};
    assert(number>0 && number<7);
    return seg_regs[number];
}

FERegisterName beu_register8_from_argtype(Int32 argtype, Int32 argposition) {
    if(argposition == 0) {
        if(argtype & REG0) return kAL;
        if(argtype & REG1) return kCL;
        if(argtype & REG2) return kDL;
        if(argtype & REG3) return kBL;
    } else if(argposition == 1){
        if(argtype & REG0) return kAH;
        if(argtype & REG1) return kCH;
        if(argtype & REG2) return kDH;
        if(argtype & REG3) return kBH;
    }
    
    assert(false);
    @throw [NSException new];
}

FERegisterName beu_register_from_argtype(Int32 argtype, Int32 argposition, FEBitWidth bitWidth) {
    switch (bitWidth) {
        case k8bit:
            return beu_register8_from_argtype(argtype, argposition);
            break;
        case k16bit:
            return beu_register16_from_argtype(argtype, argposition);
            break;
        case k32bit:
            return beu_register32_from_argtype(argtype, argposition);
            break;
        default:
            assert(false);
            break;
    }
}

uint32_t beu_address_from_argtype(ARGTYPE * address_arg, FEProcessContext *process) {
    uint32_t baseRegister = 0;
    uint32_t indexRegister = 0;
    
    if(address_arg->Memory.BaseRegister != 0) {
        FERegisterName baseRegisterName = beu_register32_from_argtype(address_arg->Memory.BaseRegister, 0);
        baseRegister = fe_threadContext_register32(process->currentThread, baseRegisterName);
    }
    
    if(address_arg->Memory.IndexRegister != 0) {
        FERegisterName indexRegisterName = beu_register32_from_argtype(address_arg->Memory.IndexRegister, 0);
        indexRegister = fe_threadContext_register32(process->currentThread, indexRegisterName);
    }

    FERegisterName segRegisterName = beu_seg_register_from_number(address_arg->SegmentReg);
    uint16_t selector = fe_threadContext_register16(process->currentThread, segRegisterName);
    uint32_t segAddress = fe_ldt_addressWithSelector(process->ldt, selector);
    
    return segAddress + baseRegister + indexRegister*address_arg->Memory.Scale + (uint32_t)address_arg->Memory.Displacement;
}

uint8_t beu_load_8bit(ARGTYPE * address_arg, FEProcessContext *process) {
    assert(address_arg->ArgType & MEMORY_TYPE);
    assert(address_arg->ArgSize == 8);
    //  assert(address_arg->AccessMode == READ);
    //TODO: segment reg ?
    return fe_memoryMap_value8AtAddress(process->memory, beu_address_from_argtype(address_arg, process));
}

uint16_t beu_load_16bit(ARGTYPE * address_arg, FEProcessContext *process) {
    assert(address_arg->ArgType & MEMORY_TYPE);
    assert(address_arg->ArgSize == 16);
    //TODO: segment reg ?
    
    return fe_memoryMap_value16AtAddress(process->memory, beu_address_from_argtype(address_arg, process));
}

uint32_t beu_load_32bit(ARGTYPE * address_arg, FEProcessContext *process) {
    assert(address_arg->ArgType & MEMORY_TYPE);
    assert(address_arg->ArgSize == 32);
    //TODO: segment reg ?
    
    return fe_memoryMap_value32AtAddress(process->memory, beu_address_from_argtype(address_arg, process));
}

uint32_t beu_load(ARGTYPE * address_arg, FEProcessContext *process, FEBitWidth bitWidth) {
    switch (bitWidth) {
        case k8bit:
            return beu_load_8bit(address_arg, process);
            break;
        case k16bit:
            return beu_load_16bit(address_arg, process);
            break;
        case k32bit:
            return beu_load_32bit(address_arg, process);
            break;
        default:
            assert(false);
            break;
    }
}

void beu_store_8bit(uint8_t value, ARGTYPE *address_arg, FEProcessContext *process) {
    assert(address_arg->ArgType & MEMORY_TYPE);
    assert(address_arg->ArgSize == 8);
    assert(address_arg->AccessMode == WRITE);
    
    fe_memoryMap_setValue8(process->memory, beu_address_from_argtype(address_arg, process), value);
}

void beu_store_16bit(uint16_t value, ARGTYPE *address_arg, FEProcessContext *process) {
    assert(address_arg->ArgType & MEMORY_TYPE);
    assert(address_arg->ArgSize == 16);
    assert(address_arg->AccessMode == WRITE);
    
    fe_memoryMap_setValue16(process->memory, beu_address_from_argtype(address_arg, process), value);
}

void beu_store_32bit(uint32_t value, ARGTYPE *address_arg, FEProcessContext *process) {
    assert(address_arg->ArgType & MEMORY_TYPE);
    assert(address_arg->ArgSize == 32);
    assert(address_arg->AccessMode == WRITE);
    
    fe_memoryMap_setValue32(process->memory, beu_address_from_argtype(address_arg, process), value);
    
}

void beu_store(uint32_t value, ARGTYPE *address_arg, FEProcessContext *process, FEBitWidth bitWidth) {
    switch (bitWidth) {
        case k8bit:
            beu_store_8bit(value, address_arg, process);
            break;
        case k16bit:
            beu_store_16bit(value, address_arg, process);
            break;
        case k32bit:
            beu_store_32bit(value, address_arg, process);
            break;
        default:
            assert(false);
            break;
    }
}
