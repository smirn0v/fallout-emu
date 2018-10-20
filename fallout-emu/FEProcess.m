//
//  FEProcess.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 14/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEProcess.h"

#include "FEMemoryMap.h"
#include "FEMemoryMapBlock.h"

#include "FEThreadContext.h"
#import "FEImportsProxy.h"
#include "FELocalDescriptorTable.h"
#import "FEKernel32DLL.h"
#import "FEUser32DLL.h"
#import "FEGDI32DLL.h"
#import "FEMSVCRTDLL.h"
#import "FEDDrawDLL.h"
#import "FEDInputDLL.h"
#import "FEDSoundDLL.h"
#import "FEWinmmDLL.h"
#import "FEPEReadException.h"
#import "FEMemoryAccessException.h"
#import "FEFPU.h"
#import "NSString+FE.h"

#include "FEMemoryMap.h"
#include "FEStack.h"
#include "cutils.h"
#include "beaengine/BeaEngine.h"
#include <sys/types.h>

#include <math.h>
#include <mach/mach_time.h>

#import "beaengine_utils.h"

#import "pe.h"

uint32_t time_passed() {
    const int64_t kOneMillion = 1000 * 1000;
    static mach_timebase_info_data_t s_timebase_info;
    
    if (s_timebase_info.denom == 0) {
        (void) mach_timebase_info(&s_timebase_info);
    }
    
    // mach_absolute_time() returns billionth of seconds,
    // so divide by one million to get milliseconds
    return  (uint32_t)((mach_absolute_time() * s_timebase_info.numer) / (kOneMillion * s_timebase_info.denom));
}

void memoryMapAccessModeChange(FEMemoryMap *memory, FEMemoryAccessMode accessMode, uint32_t address, uint32_t size) {
    FEMemoryMapBlock *block = fe_memoryMap_blockFromVirtualAddress(memory, address);
    if(block && block->context) {
        // it's much more easier to drop whole cache instead of trying
        // to re-sort it.
        DisasmContext *context = block->context;
        free(context->indexes);
        fe_array_release(context->disasmed);
        fe_array_release(context->lens);
        free(context);
        block->context = NULL;
    }
}

void instruction_fpu_dc(DISASM **op, uint8_t modrm, FEProcessContext *process);
void instruction_fpu_d8(DISASM **op, uint8_t modrm, FEProcessContext *process);
void instruction_fpu_dd(DISASM **op, uint8_t modrm, FEProcessContext *process);
void instruction_fpu_df(DISASM **op, uint8_t modrm, FEProcessContext *process);
void instruction_fpu_de(DISASM **op, uint8_t modrm, FEProcessContext *process);
void instruction_fpu_d9(DISASM **op, uint8_t modrm, FEProcessContext *process);
void instruction_fpu_db(DISASM **op, uint8_t modrm, FEProcessContext *process);
void instruction_fpu_9b(DISASM **op, uint8_t modrm, FEProcessContext *process);

void instruction_ff(DISASM **op, uint8_t *modrm, int *len, FEProcess *process, BOOL *should_continue);
void instruction_80_81(DISASM **op, FEProcessContext *process);
void instruction_83(DISASM **op, FEProcessContext *process);
void instruction_f6(DISASM **op, FEProcessContext *process);
void instruction_f7(DISASM **op, FEProcessContext *process);

@implementation FEProcess {
    NSMutableDictionary *_instructionsUsageFrequency;
    FEMemoryMap *_memory;
    FEProcessContext *_processContext;
    FEThreadContext *_mainThread;
    FEThreadContext *_currentThread;
    FELocalDescriptorTable *_ldt;
    FEImportsProxy *_importsProxy;
    pe_ctx_t pe_ctx;
    
    uint16_t _cs;
    uint16_t _ds;
    uint16_t _ss;
    uint16_t _es;
    
    BOOL _exit;
    uint32_t _exitCode;
    
    uint64_t _instruction_counter;
    
    NSMutableString *_stdoutBuffer;

}

- (instancetype)initWithPathToExecutable:(NSString*) path diskCPath:(NSString*) diskCPath {
    if(self = [super init]) {
        
        _processContext = malloc(sizeof(FEProcessContext));
        assert(_processContext);
        
        _instructionsUsageFrequency = @{}.mutableCopy;

        _stdoutBuffer = [[NSMutableString alloc] init];
        _path = [path copy];
        _diskCPath = [diskCPath copy];
        uint32_t memorySize = /*1GB*/1*1024*1024*1024;
        
        _ldt = fe_ldt_create();
        
        // seperate for code segment. got this from ollydbg. As all of them are mapped to 0, don't think
        // it makes any difference.
        _cs = fe_ldt_createLDWithAddress(_ldt, 0, memorySize);
        _ds = fe_ldt_createLDWithAddress(_ldt, 0, memorySize);
        _ss = _ds;
        _es = _ds;
        
        _memory = fe_memoryMap_create(memorySize);
        
        FEMemoryMapBlock *zeroBlock = fe_memoryMapBlock_create(".zero-page");
        zeroBlock->localAddress = 0;
        zeroBlock->virtualAddress = 0;
        zeroBlock->size = 4*1024;
        zeroBlock->end = zeroBlock->virtualAddress+zeroBlock->size;
        zeroBlock->freeWhenDone = 0;
        
        assert(zeroBlock);
        fe_memoryMap_map(_memory, zeroBlock, 0);
        

        
        NSString *onDiskPath = [path fe_win_convertToRealPathWithDiskAtPath: _diskCPath currentPath:nil];
        pe_err_e error = pe_load_file(&pe_ctx, [onDiskPath cStringUsingEncoding: NSASCIIStringEncoding]);
        if(error != LIBPE_E_OK) {
            @throw [[FEPEReadException alloc] initWithName: @"FEPEReadException"
                                                    reason: @"Failed to open file"
                                                  userInfo: nil];
        }
        
        error = pe_parse(&pe_ctx);
        if(error != LIBPE_E_OK) {
            @throw [[FEPEReadException alloc] initWithName: @"FEPEReadException"
                                                    reason: @"Failed to parse PE file"
                                                  userInfo: nil];
        }
        
        [self mapSectionsFromPE];
        [self setUpImports];
        [self createMainThread];
        
        _memory->memoryMapAccessModeChangeCallback = memoryMapAccessModeChange;
        
        _processContext->memory = _memory;
        _processContext->ldt = _ldt;
        _processContext->currentThread = _currentThread;
    }
    return self;
}

- (NSString*) currentRealPath {
    return [[_path fe_win_convertToRealPathWithDiskAtPath: _diskCPath currentPath: nil] stringByDeletingLastPathComponent];
}

- (NSArray*) instructionsUsageFrequency {
    return [_instructionsUsageFrequency keysSortedByValueUsingSelector:@selector(compare:)];
}


- (void) mapSectionsFromPE {
    for(uint16_t i = 0; i < pe_ctx.pe.num_sections; i++) {
        BOOL freeWhenDone = NO;
        IMAGE_SECTION_HEADER* section_header = pe_ctx.pe.sections[i];
        NSString* tag = [NSString fe_stringFromASCIIcstr: (char*)section_header->Name];
        
        FEMemoryAccessMode accessMode = 0;
        if(section_header->Characteristics & IMAGE_SCN_MEM_READ) {
            accessMode |= kFEMemoryAccessMode_Read;
        }
        if(section_header->Characteristics & IMAGE_SCN_MEM_WRITE) {
            accessMode |= kFEMemoryAccessMode_Write;
        }
        if(section_header->Characteristics & IMAGE_SCN_MEM_EXECUTE) {
            accessMode |= kFEMemoryAccessMode_Execute;
        }
        
        char* localAddr = pe_ctx.map_addr + section_header->PointerToRawData;
        if(section_header->Characteristics & IMAGE_SCN_CNT_UNINITIALIZED_DATA) {
            localAddr = malloc(section_header->SizeOfRawData);
            assert(localAddr);
            memset(localAddr,0,section_header->SizeOfRawData);
            freeWhenDone = YES;
        }
        uint32_t vaddr = (uint32_t)(section_header->VirtualAddress + pe_ctx.pe.imagebase);
        FEMemoryMapBlock *block = fe_memoryMapBlock_create([tag cStringUsingEncoding: NSASCIIStringEncoding]);
        block->localAddress = localAddr;
        block->virtualAddress = vaddr;
        block->size = section_header->SizeOfRawData;
        block->end = block->virtualAddress+block->size;
        block->freeWhenDone = freeWhenDone;
        
        if(section_header->SizeOfRawData < section_header->Misc.VirtualSize) {
            uint32_t appendix_size = section_header->Misc.VirtualSize - section_header->SizeOfRawData;
            block->size += appendix_size;
            block->end = block->virtualAddress+block->size;
            block->localAddress = calloc(block->size,1);
            memcpy(block->localAddress, localAddr, section_header->SizeOfRawData);
            block->freeWhenDone = 1;
        }
        
        fe_memoryMap_map(_memory, block, accessMode);
    }
}

- (void) setUpImports {
    uint32_t idataAddr = 0;
    uint32_t idataSize = 0;
    FEMemoryMapBlock* importsBlock = fe_memoryMap_blockWithTag(_memory, ".idata");
    

    if(importsBlock) {
        idataAddr = importsBlock->virtualAddress;
        idataSize = importsBlock->size;
    } else if(pe_ctx.pe.num_directories >= 2) {
        idataAddr = pe_ctx.pe.directories[1]->VirtualAddress + (uint32_t)pe_ctx.pe.imagebase;
        idataSize = pe_ctx.pe.directories[1]->Size;
    }
    
    if(idataAddr != 0) {
        _importsProxy = [[FEImportsProxy alloc] initWithMemoryMap: _memory
                                                     idataAddress: idataAddr
                                                        idataSize: idataSize
                                                        imageBase: (uint32_t)pe_ctx.pe.imagebase];
        [_importsProxy registerProxy: [FEKernel32DLL new] forDLLWithName: @"kernel32.dll"];
        [_importsProxy registerProxy: [FEUser32DLL new] forDLLWithName: @"user32.dll"];
        [_importsProxy registerProxy: [FEGDI32DLL new] forDLLWithName: @"gdi32.dll"];
        [_importsProxy registerProxy: [FEMSVCRTDLL new] forDLLWithName: @"msvcrt.dll"];
        [_importsProxy registerProxy: [FEDDrawDLL new] forDLLWithName: @"ddraw.dll"];
        [_importsProxy registerProxy: [FEDInputDLL new] forDLLWithName: @"dinput.dll"];
        [_importsProxy registerProxy: [FEDSoundDLL new] forDLLWithName: @"dsound.dll"];
        [_importsProxy registerProxy: [FEWinmmDLL new] forDLLWithName:@"winmm.dll"];
    }
}

- (void) createMainThread {
    _mainThread = fe_threadContext_create(_memory, pe_ctx.pe.optional_hdr._32->SizeOfStackReserve);
    _mainThread->eip = (uint32_t)(pe_ctx.pe.entrypoint+pe_ctx.pe.imagebase);
    [self addThread: _mainThread];
    _currentThread = _mainThread;
}

- (void) addThread:(FEThreadContext*) threadContext {
    uint16_t fs = fe_ldt_createLDWithAddress(_ldt, threadContext->TIBAddress, 3*1024);
    
    threadContext->fs = fs;
    threadContext->cs = _cs;
    threadContext->ds = _ds;
    threadContext->es = _es;
    threadContext->ss = _ss;
}

- (void) removeThread:(FEThreadContext*) threadContext {
    
}

- (uint32_t) run {
    DISASM *op;
    int len = 0;

    
    uint8_t modrm;
    
    beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
    
    _instruction_counter = 0;
    double time_start = (double)time_passed();
    while(!_exit) {
/*@autoreleasepool*/ {
            
            _instruction_counter++;
            
            if(_instruction_counter % 10000000 == 0) {
                double time = (double)time_passed();
                //printf("PERF: %.2f instructions/millisecond. Instructions done: %llu M, time passed: %f\n", _instruction_counter/(time-time_start),_instruction_counter/1000000,time-time_start);
                _instrPerMillisecond =_instruction_counter/(time-time_start);
                _instrCounter = _instruction_counter;
                
            }

            //printf("%s\n", op->CompleteInstr);
            if(op->Instruction.Category & GENERAL_PURPOSE_INSTRUCTION) {
                
#define repxx_prefix    {\
                            if(op->Prefix.Number != 0) {\
                                assert(op->Prefix.LockPrefix==0);\
                                if(op->Prefix.RepnePrefix == 1 || op->Prefix.RepPrefix ==1) {\
                                    uint32_t ecx = _currentThread->ecx;\
                                    if(ecx == 0) {\
                                        goto jump_to_next_instr;\
                                    }\
                                }\
                            }\
                        }
                
                /*
                 ZF flag should be checked only for these instructions
                 
                 F3 A6	REPE CMPS m8, m8	Find nonmatching bytes in ES:[(E)DI] and DS:[(E)SI].
                 F3 A7	REPE CMPS m16, m16	Find nonmatching words in ES:[(E)DI] and DS:[(E)SI].
                 F3 A7	REPE CMPS m32, m32	Find nonmatching doublewords in ES:[(E)DI] and DS:[(E)SI].
                 F3 AE	REPE SCAS m8	Find non-AL byte starting at ES:[(E)DI].
                 F3 AF	REPE SCAS m16	Find non-AX word starting at ES:[(E)DI].
                 F3 AF	REPE SCAS m32	Find non-EAX doubleword starting at ES:[(E)DI].
                 */
#define repxx_postfix {\
                            if(op->Prefix.Number != 0) {\
                                assert(op->Prefix.LockPrefix==0);\
                                if(op->Prefix.RepnePrefix == 1) {\
                                    uint32_t ecx = _currentThread->ecx;\
                                    ecx--;\
                                    _currentThread->ecx = ecx;\
                                    if(_currentThread->cpuFlags.ZF == 1) {\
                                        goto jump_to_next_instr;\
                                    }\
                                    continue;\
                                } else if(op->Prefix.RepPrefix == 1) {\
                                    uint32_t ecx = _currentThread->ecx;\
                                    ecx--;\
                                    _currentThread->ecx = ecx;\
                                    if(op->Instruction.Opcode == 0xa6 || op->Instruction.Opcode == 0xa7 ||\
                                       op->Instruction.Opcode == 0xae || op->Instruction.Opcode == 0xaf) {\
                                        if(_currentThread->cpuFlags.ZF == 0) {\
                                            goto jump_to_next_instr;\
                                        }\
                                    }\
                                    continue;\
                                }\
                            }\
                      }

                
                switch(op->Instruction.Opcode) {
                    case 0x88:
                    case 0x89:
                    case 0x8a:
                    case 0x8b:
                    case 0x8c:
                    case 0x8e:
                    case 0xa0:
                    case 0xa1:
                    case 0xa2:
                    case 0xa3:
                    case 0xb0:
                    case 0xb1:
                    case 0xb2:
                    case 0xb3:
                    case 0xb4:
                    case 0xb5:
                    case 0xb6:
                    case 0xb7:
                    case 0xb8: //0
                    case 0xb9: //1
                    case 0xba: //2
                    case 0xbb: //3
                    case 0xbc: //4
                    case 0xbd: //5
                    case 0xbe: //6
                    case 0xbf: {
                        //assert(strcmp(op->Instruction.Mnemonic,"mov ")==0);
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                    }
                        break;
                        /*
                         FF /6	PUSH r/m16	Push r/m16.
                         FF /6	PUSH r/m32	Push r/m32.
                         
                         50+rw	PUSH r16	Push r16.
                         50+rd	PUSH r32	Push r32.
                         6A	PUSH imm8	Push imm8.
                         68	PUSH imm16	Push imm16.
                         68	PUSH imm32	Push imm32.
                   
                         */
                    case 0x50:
                    case 0x51:
                    case 0x52:
                    case 0x53:
                    case 0x54:
                    case 0x55:
                    case 0x56:
                    case 0x57:
                    case 0x6a:
                    case 0x68: {
                        uint32_t value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        fe_stack_push(_currentThread->stack, value, (FEBitWidth)op->Argument2.ArgSize);
                    }
                        break;
                        /*
                         0E	PUSH CS	Push CS.
                         16	PUSH SS	Push SS.
                         1E	PUSH DS	Push DS.
                         06	PUSH ES	Push ES.
                         0F A0	PUSH FS	Push FS.
                         0F A8	PUSH GS	Push GS.
                         */
                    case 0x0e:
                    case 0x16:
                    case 0x1e:
                    case 0x06:
                    case 0xfa0:
                    case 0xfa8: {
                        //xxx
                        //                assert(op->Argument2.ArgSize == 32);
                        //assert(strcmp(op->Instruction.Mnemonic,"push ")==0);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        fe_stack_push32(_currentThread->stack, arg2Value);
                    }
                        break;
                    case 0x0:
                    case 0x1:
                    case 0x2:
                    case 0x3:
                    case 0x4:
                    case 0x5: { //add
                        //assert(strcmp(op->Instruction.Mnemonic,"add ")==0);
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t result = fe_threadContext_add(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                        /*
                         1F	POP DS	Pop top of stack into DS; increment stack pointer.
                         07	POP ES	Pop top of stack into ES; increment stack pointer.
                         17	POP SS	Pop top of stack into SS; increment stack pointer.
                         0F A1	POP FS	Pop top of stack into FS; increment stack pointer.
                         0F A9	POP GS
                         */
                    case 0x1f:
                    case 0x07:
                    case 0x17:
                    case 0xfa1:
                    case 0xfa9: { // pop 16bit $es
                        //assert(strcmp(op->Instruction.Mnemonic,"pop ")==0);
                        uint16_t value = fe_stack_pop32(_currentThread->stack);

                        beu_store_value_in_arg(&op->Argument1, value, _processContext);
                    }
                        break;
                        /*
                         1C ib	SBB AL,imm8	Subtract with borrow imm8 from AL.
                         1D iw	SBB AX,imm16	Subtract with borrow imm16 from AX.
                         1D id	SBB EAX,imm32	Subtract with borrow imm32 from EAX.
                         80 /3 ib	SBB r/m8,imm8	Subtract with borrow imm8 from r/m8.
                         81 /3 iw	SBB r/m16,imm16	Subtract with borrow imm16 from r/m16.
                         81 /3 id	SBB r/m32,imm32	Subtract with borrow imm32 from r/m32.
                         83 /3 ib	SBB r/m16,imm8	Subtract with borrow sign-extended imm8 from r/m16.
                         83 /3 ib	SBB r/m32,imm8	Subtract with borrow sign-extended imm8 from r/m32.
                         18 /r	SBB r/m8,r8	Subtract with borrow r8 from r/m8.
                         19 /r	SBB r/m16,r16	Subtract with borrow r16 from r/m16.
                         19 /r	SBB r/m32,r32	Subtract with borrow r32 from r/m32.
                         1A /r	SBB r8,r/m8	Subtract with borrow r/m8 from r8.
                         1B /r	SBB r16,r/m16	Subtract with borrow r/m16 from r16.
                         1B /r	SBB r32,r/m32	Subtract with borrow r/m32 from r32.
                         */
                    case 0x1c:
                    case 0x1d:
                    case 0x18:
                    case 0x19:
                    case 0x1a:
                    case 0x1b: {
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t result = fe_threadContext_sbb(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                    case 0x08:
                    case 0x09:
                    case 0xa:
                    case 0xb:
                    case 0xc:
                    case 0xd: {
                        //assert(strcmp(op->Instruction.Mnemonic,"or ")==0);
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t result = fe_threadContext_or(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                    case 0x20:
                    case 0x21:
                    case 0x22:
                    case 0x23:
                    case 0x24:
                    case 0x25: {
                        //assert(strcmp(op->Instruction.Mnemonic,"and ")==0);
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        uint32_t result = fe_threadContext_and(_currentThread, arg1Value, arg2Value, (FEBitWidth) op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                        /*
                         2C ib	SUB AL,imm8	Subtract imm8 from AL.
                         2D iw	SUB AX,imm16	Subtract imm16 from AX.
                         2D id	SUB EAX,imm32	Subtract imm32 from EAX.
                         28 /r	SUB r/m8,r8	Subtract r8 from r/m8.
                         29 /r	SUB r/m16,r16	Subtract r16 from r/m16.
                         29 /r	SUB r/m32,r32	Subtract r32 from r/m32.
                         2A /r	SUB r8,r/m8	Subtract r/m8 from r8.
                         2B /r	SUB r16,r/m16	Subtract r/m16 from r16.
                         2B /r	SUB r32,r/m32	Subtract r/m32 from r32.
                         */
                    case 0x2c:
                    case 0x2d:
                    case 0x28:
                    case 0x29:
                    case 0x2a:
                    case 0x2b: { // sub 32bit gen reg 32bit gen reg
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t result = fe_threadContext_sub(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                    case 0x27: {
                        //DAA
                        /*
                         old_AL ← AL;
                         old_CF ← CF;
                         CF ← 0;
                         IF (((AL AND 0FH) > 9) or AF = 1)
                         THEN
                             AL ← AL + 6;
                             CF ← old_CF or (Carry from AL ← AL + 6);
                             AF ← 1; 
                         ELSE
                             AF ← 0;
                         FI;
                         IF ((old_AL > 99H) or (old_CF = 1)) THEN
                             AL ← AL + 60H;
                             CF ← 1;
                         ELSE
                             CF ← 0;
                         FI;
                         */
                        uint8_t old_al = fe_threadContext_register8(_currentThread, kAL);
                        char old_cf = _currentThread->cpuFlags.CF;
                        _currentThread->cpuFlags.CF = 0;
                        if( ((old_al & 0x0f)>9) || _currentThread->cpuFlags.AF == 1) {
                            fe_threadContext_setRegister8(_currentThread, kAL, old_al+6);
                            _currentThread->cpuFlags.CF = old_cf || beu_carry_for_8(old_al, 6);
                            _currentThread->cpuFlags.AF = 1;
                        } else {
                            _currentThread->cpuFlags.AF = 0;
                        }
                        if((old_al > 0x99) || (old_cf == 1)) {
                            uint8_t al = fe_threadContext_register8(_currentThread, kAL);
                            fe_threadContext_setRegister8(_currentThread, kAL, al+0x60);
                            _currentThread->cpuFlags.CF = 1;
                        } else {
                            _currentThread->cpuFlags.CF = 0;
                        }
                        uint8_t al = fe_threadContext_register8(_currentThread, kAL);
                        fe_cpuflags_fillParityFromByte(&_currentThread->cpuFlags, al);
                        _currentThread->cpuFlags.SF = (al>>7)&1;
                        _currentThread->cpuFlags.ZF = al == 0;
                    }
                        break;
                    case 0x2f: {
                        //das
                        /*
                         old_AL ← AL;
                         old_CF ← CF;
                         CF ← 0;
                         IF (((AL AND 0FH) > 9) or AF = 1)
                         THEN
                             AL ← AL - 6;
                             CF ← old_CF or (Borrow from AL ← AL − 6);
                             AF ← 1; 
                         ELSE
                             AF ← 0;
                         FI;
                         IF ((old_AL > 99H) or (old_CF = 1)) THEN
                             AL ← AL − 60H;
                             CF ← 1; 
                         FI;
                         */
                        uint8_t old_al = fe_threadContext_register8(_currentThread, kAL);
                        char old_cf = _currentThread->cpuFlags.CF;
                        _currentThread->cpuFlags.CF = 0;
                        if(((old_al & 0x0f)>9) || _currentThread->cpuFlags.AF ==1) {
                            fe_threadContext_setRegister8(_currentThread, kAL, old_al - 6);
                            _currentThread->cpuFlags.CF = old_cf || (old_al<6);
                            _currentThread->cpuFlags.AF = 1;
                        } else {
                            _currentThread->cpuFlags.AF = 0;
                        }
                        if((old_al > 0x99) || (old_cf == 1)) {
                            uint8_t al = fe_threadContext_register8(_currentThread, kAL);
                            fe_threadContext_setRegister8(_currentThread, kAL, al - 0x60);
                            _currentThread->cpuFlags.CF = 1;
                        }
                        uint8_t al = fe_threadContext_register8(_currentThread, kAL);
                        fe_cpuflags_fillParityFromByte(&_currentThread->cpuFlags, al);
                        _currentThread->cpuFlags.SF = (al>>7)&1;
                        _currentThread->cpuFlags.ZF = al == 0;
                    }
                        break;
                    case 0x37: {
                        //aaa
                        /*
                         IF ((AL AND 0FH) > 9) or (AF = 1) THEN
                             AX ← AX + 106H;
                             AF ← 1;
                             CF ← 1;
                         ELSE
                             AF ← 0;
                             CF ← 0; 
                         FI;
                         AL ← AL AND 0FH;
                         */
                        uint8_t al = fe_threadContext_register8(_currentThread, kAL);

                        if(((al & 0xf) > 9) || (_currentThread->cpuFlags.AF==1)) {
                            uint16_t ax = fe_threadContext_register16(_currentThread, kAX);
                            fe_threadContext_setRegister16(_currentThread, kAX, ax + 0x106);
                            _currentThread->cpuFlags.AF = 1;
                            _currentThread->cpuFlags.CF = 1;
                        } else {
                            _currentThread->cpuFlags.AF = 0;
                            _currentThread->cpuFlags.CF = 0;
                        }
                        al = fe_threadContext_register8(_currentThread, kAL);
                        fe_threadContext_setRegister8(_currentThread, kAL, al & 0xf);
                        fe_cpuflags_fillParityFromByte(&_currentThread->cpuFlags, al);
                        _currentThread->cpuFlags.SF = (al>>7)&1;
                        _currentThread->cpuFlags.ZF = al == 0;
                    }
                        break;
                    case 0x3f: {
                        //aas
                        /*
                         IF ((AL AND 0FH) > 9) or (AF = 1) THEN
                             AX ← AX – 6; 
                             AH ← AH – 1; 
                             AF ← 1;
                             CF ← 1;
                             AL ← AL AND 0FH;
                         ELSE
                             CF ← 0;
                             AF ← 0;
                             AL ← AL AND 0FH;
                         FI;
                         */
                        uint8_t al = fe_threadContext_register8(_currentThread, kAL);
                        if(((al & 0xf) > 9) || (_currentThread->cpuFlags.AF==1)) {
                            
                            uint16_t ax = fe_threadContext_register16(_currentThread, kAX);
                            fe_threadContext_setRegister16(_currentThread, kAX, ax - 6);
                            
                            uint8_t ah = fe_threadContext_register8(_currentThread, kAH);
                            fe_threadContext_setRegister8(_currentThread, kAH, ah - 1);
                            
                            _currentThread->cpuFlags.AF = 1;
                            _currentThread->cpuFlags.CF = 1;
                            al = fe_threadContext_register8(_currentThread, kAL);
                            fe_threadContext_setRegister8(_currentThread, kAL, al & 0xf);
                        } else {
                            _currentThread->cpuFlags.AF = 0;
                            _currentThread->cpuFlags.CF = 0;
                            al = fe_threadContext_register8(_currentThread, kAL);
                            fe_threadContext_setRegister8(_currentThread, kAL, al & 0xf);
                        }
                        al = fe_threadContext_register8(_currentThread, kAL);

                        fe_cpuflags_fillParityFromByte(&_currentThread->cpuFlags, al);
                        _currentThread->cpuFlags.SF = (al>>7)&1;
                        _currentThread->cpuFlags.ZF = al == 0;

                    }
                        break;
                    case 0x30:
                    case 0x31:
                    case 0x32:
                    case 0x33:
                    case 0x34:
                    case 0x35: {
                        //assert(strcmp(op->Instruction.Mnemonic,"xor ")==0);
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg1Val = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Val = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t result = fe_threadContext_xor(_currentThread, arg1Val, arg2Val, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                    case 0x38:
                    case 0x39:
                    case 0x3a:
                    case 0x3b:
                    case 0x3c:
                    case 0x3d: {
                        //assert(strcmp(op->Instruction.Mnemonic,"cmp ")==0);
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        fe_threadContext_sub(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                    }
                        break;
                        /*
                         FE		0						INC	r/m8						o..szap.	o..szap.			Increment by 1
                         FE		1						DEC	r/m8						o..szap.	o..szap.			Decrement by 1
                         */
                    case 0xfe: {
                        if(op->Reserved_.REGOPCODE == 0) {
                            uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                            uint32_t result = fe_threadContext_inc(_currentThread, arg1Value, (FEBitWidth)op->Argument1.ArgSize);
                            beu_store_value_in_arg(&op->Argument1, result, _processContext);
                        } else if(op->Reserved_.REGOPCODE == 1) {
                            uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                            uint32_t result = fe_threadContext_dec(_currentThread, arg1Value, (FEBitWidth)op->Argument1.ArgSize);
                            
                            beu_store_value_in_arg(&op->Argument1, result, _processContext);
                        } else {
                            assert(false);
                        }
                    }
                        break;
                    case 0x40:
                    case 0x41:
                    case 0x42:
                    case 0x43:
                    case 0x44:
                    case 0x45:
                    case 0x46:
                    case 0x47: { //inc
                        //assert(strcmp(op->Instruction.Mnemonic,"inc ")==0);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t result = fe_threadContext_inc(_currentThread, arg1Value, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                        /*
                         14 ib	ADC AL, imm8	Add with carry imm8 to AL
                         15 iw	ADC AX, imm16	Add with carry imm16 to AX
                         15 id	ADC EAX, imm32	Add with carry imm32 to EAX
                
                         10 /r	ADC r/m8, r8	Add with carry byte register to r/m8
                         11 /r	ADC r/m16, r16	Add with carry r16 to r/m16
                         11 /r	ADC r/m32, r32	Add with CF r32 to r/m32
                         12 /r	ADC r8, r/m8	Add with carry r/m8 to byte register
                         13 /r	ADC r16, r/m16	Add with carry r/m16 to r16
                         13 /r	ADC r32, r/m32	Add with CF r/m32 to r32
                         */
                    case 0x14:
                    case 0x15:
                    case 0x10:
                    case 0x11:
                    case 0x12:
                    case 0x13: {
                        //XXX need to set carry flag
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t result = fe_threadContext_adc(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                    case 0x48:
                    case 0x49:
                    case 0x4a:
                    case 0x4b:
                    case 0x4c:
                    case 0x4d:
                    case 0x4e:
                    case 0x4f:{ //dec
                        //assert(strcmp(op->Instruction.Mnemonic,"dec ")==0);
                        
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t result = fe_threadContext_dec(_currentThread, arg1Value, (FEBitWidth)op->Argument1.ArgSize);
                        
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                        
                    case 0x8f:
                    case 0x58:
                    case 0x59:
                    case 0x5a:
                    case 0x5b:
                    case 0x5c:
                    case 0x5d:
                    case 0x5e:
                    case 0x5f:{ // pop 32bit general register
                        //assert(strcmp(op->Instruction.Mnemonic,"pop ")==0);


                        // XXX
                        //assert(op->Argument1.ArgSize == 32);
                        
                        uint32_t value = fe_stack_pop(_currentThread->stack, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, value, _processContext);
                        
                        
                    }
                        break;
                    case 0x69:
                    case 0x6b: {
                        //imul
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint64_t result;
                        if(!op->Reserved_.third_arg) {
                            result = fe_threadContext_imul32(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                        } else {
                            uint32_t arg3Value = beu_load_arg_value(&op->Argument3,
                                                                    (uint32_t)op->Instruction.Immediat, _processContext);
                            result = fe_threadContext_imul32(_currentThread, arg2Value, arg3Value, (FEBitWidth)op->Argument2.ArgSize);
                        }
                        beu_store_value_in_arg(&op->Argument1, (uint32_t)result, _processContext);
                    }
                        break;
                        
                    case 0xf82:
                    case 0x72: {
                        //assert(strcmp(op->Instruction.Mnemonic,"jc ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.CF == 1) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0xf80:
                    case 0x70: {
                        //assert(strcmp(op->Instruction.Mnemonic,"jc ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.OF == 1) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0xf83:
                    case 0x73: { //jncl 32bit
                        //assert(strcmp(op->Instruction.Mnemonic,"jnc ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.CF != 1) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                    case 0xf84:
                    case 0x74: { //jel $004EC8CAh 32bit
                        //assert(strcmp(op->Instruction.Mnemonic,"je ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.ZF == 1) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0xf85:
                    case 0x75: {
                        //assert(strcmp(op->Instruction.Mnemonic,"jne ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.ZF == 0) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                    case 0xf86:
                    case 0x76: {
                        //assert(strcmp(op->Instruction.Mnemonic,"jbe ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        //CF=1 or ZF=1
                        if(_currentThread->cpuFlags.CF == 1 || _currentThread->cpuFlags.ZF == 1) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                        
                    }
                        break;
                    case 0xf87:
                    case 0x77: { //jnbel $004EC8CAh
                        //assert(strcmp(op->Instruction.Mnemonic,"jnbe ")==0 || strcmp(op->Instruction.Mnemonic,"ja ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.CF == 0 && _currentThread->cpuFlags.ZF == 0) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                    case 0xf88:
                    case 0x78: {
                        //Jump short if sign (SF=1).
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.SF == 1) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0xf89:
                    case 0x79: {
                        //Jump short if not sign (SF=0)
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.SF == 0) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                        
                    case 0xf8a:
                    case 0x7a: {
                        //Jump short if not sign (PF=1)
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.PF == 1) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                        
                    case 0xf8b:
                    case 0x7b: {
                        //Jump short if not sign (PF=0)
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.PF == 0) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0xf8c:
                    case 0x7c: {
                        //assert(strcmp(op->Instruction.Mnemonic,"jl ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->cpuFlags.SF != _currentThread->cpuFlags.OF) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0x7d:
                    case 0xf8d: {//jnl
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        /*
                         Jump short if not less/greater or equal (SF=OF)
                         */
                        if(_currentThread->cpuFlags.SF == _currentThread->cpuFlags.OF) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0x7f:
                    case 0xf8f: { //jg
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        //Jump near if greater (ZF=0 and SF=OF).
                        if((_currentThread->cpuFlags.ZF == 0) && (_currentThread->cpuFlags.SF == _currentThread->cpuFlags.OF)) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0x71:
                    case 0xf81: {
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);

                        if(_currentThread->cpuFlags.OF == 0) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                        
                    case 0x7e:
                    case 0xf8e: {//jngl
                        //Jump short if less or equal/not greater ((ZF=1) OR (SF!=OF))
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);

                        if((_currentThread->cpuFlags.ZF == 1) || (_currentThread->cpuFlags.SF != _currentThread->cpuFlags.OF)) {
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                            continue;
                        }
                    }
                        break;
                    case 0x80:
                    case 0x81: {
                        instruction_80_81(&op, _processContext);
                    }
                        break;
                    case 0x83: {
                        assert(op->Argument2.ArgType & CONSTANT_TYPE);
                        assert(op->Argument2.ArgSize == 8);
                        
                        instruction_83(&op, _processContext);
                    }
                        break;
                        /*
                         A8 ib	TEST AL,imm8	AND imm8 with AL; set SF, ZF, PF according to result.
                         A9 iw	TEST AX,imm16	AND imm16 with AX; set SF, ZF, PF according to result.
                         A9 id	TEST EAX,imm32	AND imm32 with EAX; set SF, ZF, PF according to result.
                         84 /r	TEST r/m8,r8	AND r8 with r/m8; set SF, ZF, PF according to result.
                         85 /r	TEST r/m16,r16	AND r16 with r/m16; set SF, ZF, PF according to result.
                         85 /r	TEST r/m32,r32	AND r32 with r/m32; set SF, ZF, PF according to result.
                         */
                    case 0xa8:
                    case 0xa9:
                    case 0x84:
                    case 0x85: {
                        //assert(strcmp(op->Instruction.Mnemonic,"test ")==0);
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        fe_threadContext_test(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                    }
                        break;
                      
                    case 0x91:
                    case 0x92:
                    case 0x86:
                    case 0x87: {
                        //assert(strcmp(op->Instruction.Mnemonic,"xchg ")==0);
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        beu_store_value_in_arg(&op->Argument2, arg1Value, _processContext);
                    }
                        break;
                        
                    case 0x8d: { // leal -08h(%ebp), %eax
                        //assert(strcmp(op->Instruction.Mnemonic,"lea ")==0);
                        assert(op->Argument2.ArgType & MEMORY_TYPE);
                        assert(op->Argument2.ArgSize == 32);
                        assert(op->Argument1.ArgType & REGISTER_TYPE);
                        assert(op->Argument1.ArgType & GENERAL_REG);
                        assert(op->Argument1.ArgSize == 32);
                        
                        uint32_t address = beu_address_from_argtype(&op->Argument2, _processContext);
                        FERegisterName registerName = beu_register32_from_argtype(op->Argument1.ArgType, op->Argument1.ArgPosition);
                        fe_threadContext_setRegister32(_currentThread, registerName, address);
                    }
                        break;
                        
                    case 0xa6:
                    case 0xa7: {
                        repxx_prefix;
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        // weird order, but seems to be the right one. passes tests and follows documentation
                        fe_threadContext_sub(_currentThread, arg2Value, arg1Value, (FEBitWidth)op->Argument1.ArgSize);

                        uint32_t esi = _currentThread->esi;
                        uint32_t edi = _currentThread->edi;
                        uint8_t diff = op->Argument1.ArgSize / 8;
                        if(_currentThread->cpuFlags.DF == 0) {
                            esi+=diff;
                            edi+=diff;
                        } else {
                            esi-=diff;
                            edi-=diff;
                        }
                        _currentThread->esi = esi;
                        _currentThread->edi = edi;
                        repxx_postfix;
                    }
                        break;
                    case 0xaf:
                    case 0xae: { // scasb
                        repxx_prefix;
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        //printf("0x%X:%lld ", _currentThread->eip, _instruction_counter);
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        // printf("symbol: '%c', al = 0x%X, edi = 0x%X, arg1 = 0x%X ", arg2Value, _currentThread->eax, _currentThread->edi, arg1Value);
                        //printf("df = %d ",_currentThread->cpuFlags.DF);
                        fe_threadContext_sub(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);

                        uint8_t diff = op->Argument1.ArgSize / 8;
                        FERegisterName regName = beu_register32_from_argtype(op->Argument2.Memory.BaseRegister, 0);
                        uint32_t regValue = fe_threadContext_register32(_currentThread, regName);
                        //printf("diff = 0x%X, regName = 0x%X, regValue = 0x%X\n",diff,regName,regValue);
                        if(_currentThread->cpuFlags.DF == 0) {
                            regValue += diff;
                        } else {
                            regValue -= diff;
                        }
                        fe_threadContext_setRegister32(_currentThread, regName, regValue);
                        repxx_postfix;
                    }
                        break;
                        
                    case 0xaa:
                    case 0xab: {
                        repxx_prefix;
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);

                        uint32_t edi = _currentThread->edi;
                        uint8_t diff = op->Argument1.ArgSize / 8;
                        if(_currentThread->cpuFlags.DF == 0) {

                            edi+=diff;
                        } else {

                            edi-=diff;
                        }
                        _currentThread->edi = edi;
                        repxx_postfix;
                    }
                        break;
                    
                    case 0xa4:
                    case 0xa5:{
                        repxx_prefix;
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        uint32_t esi = _currentThread->esi;
                        uint32_t edi = _currentThread->edi;
                        uint8_t diff = op->Argument1.ArgSize / 8;
                        if(_currentThread->cpuFlags.DF == 0) {
                            esi+=diff;
                            edi+=diff;
                        } else {
                            esi-=diff;
                            edi-=diff;
                        }
                        _currentThread->esi = esi;
                        _currentThread->edi = edi;
                        repxx_postfix;
                    }
                        break;
                    case 0xac:
                    case 0xad: { //lods
                        repxx_prefix;
                        assert(op->Argument1.ArgSize == op->Argument2.ArgSize);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        uint32_t esi = _currentThread->esi;

                        uint8_t diff = op->Argument1.ArgSize / 8;
                        if(_currentThread->cpuFlags.DF == 0) {
                            esi+=diff;

                        } else {
                            esi-=diff;

                        }
                        _currentThread->esi = esi;
                        repxx_postfix;
                    }
                        break;
                    case 0x90: {
                        //assert(strcmp(op->Instruction.Mnemonic,"nop ")==0);
                        // NOP
                    }
                        break;
                    case 0x98: {
                        //CBW/CWDE
                        /*
                         IF OperandSize = 16 (* Instruction = CBW *) THEN
                            AX ← SignExtend(AL);
                         ELSE IF (OperandSize = 32, Instruction = CWDE)
                            EAX ← SignExtend(AX); FI;
                         ELSE (* 64-Bit Mode, OperandSize = 64, Instruction = CDQE*)
                            RAX ← SignExtend(EAX); FI;
                         */
                        if(op->Argument1.ArgSize == 32) {
                            uint16_t ax = fe_threadContext_register16(_currentThread, kAX);
                            uint8_t sign_bit = (ax>>15)&1;
                            if(sign_bit == 0) {
                                fe_threadContext_setRegister32(_currentThread, kEAX, ax);
                            } else {
                                fe_threadContext_setRegister32(_currentThread, kEAX,(uint32_t)(0xffff<<16)&ax);
                            }
                        } else if (op->Argument1.ArgSize == 16) {
                            uint16_t al = fe_threadContext_register8(_currentThread, kAL);
                            uint8_t sign_bit = (al>>7)&1;
                            if(sign_bit == 0) {
                                fe_threadContext_setRegister16(_currentThread, kAX, al);
                            } else {
                                fe_threadContext_setRegister16(_currentThread, kAX,(uint16_t)(0xff<<8)&al);
                            }
                        }
                    }
                        break;
                    case 0x99: { //cwd/cdq
                        //TODO: need tests
                        //XXX
                        /*
                         IF OperandSize = 16 (* CWD instruction *) 
                             THEN
                                DX ← SignExtend(AX);
                             ELSE IF OperandSize = 32 (* CDQ instruction *)
                                EDX ← SignExtend(EAX); 
                             FI;
                             ELSE IF 64-Bit Mode and OperandSize = 64 (* CQO instruction*)
                                RDX ← SignExtend(RAX); 
                             FI; 
                         FI;
                         */
                        if(op->Argument1.ArgSize == 32) {
                            uint32_t eax = _currentThread->eax;
                            uint8_t sign_bit = (eax>>31)&1;
                            if(sign_bit == 0) {
                                _currentThread->edx = 0;
                            } else {
                                _currentThread->edx = 0xffffffff;
                            }
                        } else if (op->Argument1.ArgSize == 16) {
                            uint16_t ax = fe_threadContext_register16(_currentThread, kAX);
                            uint8_t sign_bit = (ax>>15)&1;
                            if(sign_bit == 0) {
                                fe_threadContext_setRegister16(_currentThread, kDX, 0);
                            } else {
                                fe_threadContext_setRegister16(_currentThread, kDX, 0xffff);
                            }
                        }
                    }
                        break;
                    case 0x9c: {
                        //assert(strcmp(op->Instruction.Mnemonic,"pushfd ")==0);
                        uint32_t flags32 = fe_cpuflags_16(_currentThread->cpuFlags);
                        fe_stack_push32(_currentThread->stack, flags32);
                    }
                        break;
                        
                    case 0x9d: {
                        assert(op->Argument1.ArgType & REGISTER_TYPE);
                        assert(op->Argument1.ArgType & SPECIAL_REG);
                        assert(op->Argument1.ArgType & REG0);
                        uint32_t flags = fe_stack_pop(_currentThread->stack, (FEBitWidth)op->Argument1.ArgSize);
                        fe_cpuflags_fillFrom16it(&_currentThread->cpuFlags, flags);
                    }
                        break;
                        
                    case 0xd1:
                    case 0xd3:
                    case 0xc0:
                    case 0xc1: { //shl 8bit const 32bit reg
                        /*
                         C1		0	01+					ROL	r/m16/32	imm8					o..szapc	o..szapc	o.......		Rotate
                         C1		1	01+					ROR	r/m16/32	imm8					o..szapc	o..szapc	o.......		Rotate
                         C1		2	01+					RCL	r/m16/32	imm8				.......c	o..szapc	o..szapc	o.......		Rotate
                         C1		3	01+					RCR	r/m16/32	imm8				.......c	o..szapc	o..szapc	o.......		Rotate
                         
                         C1		4	01+					SHL	r/m16/32	imm8					o..szapc	o..sz.pc	o....a.c		Shift
                                                        SAL	r/m16/32	imm8
                         
                         C1		5	01+					SHR	r/m16/32	imm8					o..szapc	o..sz.pc	o....a.c		Shift
                         
                         C1		6	01+	U2				SAL	r/m16/32	imm8					o..szapc	o..sz.pc	o....a.c		Shift
                                                        SHL	r/m16/32	imm8
                         C1		7	01+					SAR	r/m16/32	imm8					o..szapc	o..sz.pc	o....a..		Shift
                         */
                        
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        uint32_t result = 0;
                        
                        switch(op->Reserved_.REGOPCODE) {
                            case 0: {
                                //assert(strcmp(op->Instruction.Mnemonic,"rol ")==0);
                                result = fe_threadContext_rol(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                            }
                                break;
                            case 1: {
                                //assert(strcmp(op->Instruction.Mnemonic,"ror ")==0);
                                result = fe_threadContext_ror(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                            }
                                break;
                            case 2: {
                                //assert(strcmp(op->Instruction.Mnemonic,"rcl ")==0);
                                result = fe_threadContext_rcl(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                            }
                                break;
                            case 3: {
                                //assert(strcmp(op->Instruction.Mnemonic,"rcr ")==0);
                                result = fe_threadContext_rcr(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                            }
                                break;
                            case 4:
                            case 6: {//shl
                                //assert(strcmp(op->Instruction.Mnemonic,"shl ")==0);
                                result = fe_threadContext_shl(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                            }
                                break;
                            case 5: {//shr
                                //assert(strcmp(op->Instruction.Mnemonic,"shr ")==0);
                                result = fe_threadContext_shr(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                            }
                                break;
                            case 7: {//sar
                                //assert(strcmp(op->Instruction.Mnemonic,"sar ")==0);
                                result = fe_threadContext_sar(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                            }
                                break;
                            default:
                                assert(false);
                        }
                        
                        beu_store_value_in_arg(&op->Argument1, result, _processContext);
                    }
                        break;
                    case 0xc3: { //ret
                        //assert(strcmp(op->Instruction.Mnemonic,"ret ")==0);
                        uint32_t eip = fe_stack_pop32(_currentThread->stack);
                        _currentThread->eip = eip;
                        beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                        continue;
                    }
                        break;
                    case 0xcb: {
                        //assert(strcmp(op->Instruction.Mnemonic,"ret ")==0);
                        assert(false);//never checked it
                        uint32_t eip = fe_stack_pop32(_currentThread->stack);
                        uint32_t cs = fe_stack_pop32(_currentThread->stack);
                        
                        _currentThread->eip = eip;
                        _currentThread->cs = cs;

                        beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                        continue;
                    }
                        break;
                    case 0xc2: {
                        //assert(strcmp(op->Instruction.Mnemonic,"retn ")==0);
                        uint32_t eip = fe_stack_pop32(_currentThread->stack);
                        _currentThread->eip = eip;
                        DISASM oldOp = *op;
                        beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                        uint32_t offset = beu_load_arg_value(&oldOp.Argument1, (uint32_t)oldOp.Instruction.Immediat, _processContext);
                        uint32_t esp = _currentThread->esp;
                        esp += offset;
                        _currentThread->esp = esp;
                        continue;
                    }
                        break;
                    case 0xca: {
                        //assert(strcmp(op->Instruction.Mnemonic,"retn ")==0);
                        assert(false);//never checked it
                        uint32_t eip = fe_stack_pop32(_currentThread->stack);
                        uint32_t cs = fe_stack_pop32(_currentThread->stack);
                        _currentThread->eip = eip;
                        _currentThread->cs = cs;
                        DISASM oldOp = *op;
                        beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                        uint32_t offset = beu_load_arg_value(&oldOp.Argument1, (uint32_t)oldOp.Instruction.Immediat, _processContext);
                        uint32_t esp = _currentThread->esp;
                        esp += offset;
                        _currentThread->esp = esp;
                        continue;
                    }
                        break;
                    case 0xc6:
                    case 0xc7: { //movl
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                    }
                        break;
                    case 0xc9: { //leave
                        uint32_t ebp = _currentThread->ebp;
                        _currentThread->esp = ebp;

                        ebp = fe_stack_pop32(_currentThread->stack);
                        _currentThread->ebp = ebp;

                    }
                        break;
                    case 0xd4: {
                        //aam
                        assert(modrm == 0xa);
                        /*
                         AH  tempAL / imm8; (* imm8 is set to 0AH for the AAD mnemonic *)
                         AL  tempAL MOD imm8;
                         */
                        uint8_t imm8 = 0x0a;
                        uint8_t al = fe_threadContext_register8(_currentThread, kAL);
                        fe_threadContext_setRegister8(_currentThread, kAH, al/imm8);
                        fe_threadContext_setRegister8(_currentThread, kAL, al % imm8);
                        
                        al = fe_threadContext_register8(_currentThread, kAL);
                        fe_cpuflags_fillParityFromByte(&_currentThread->cpuFlags, al);

                        _currentThread->cpuFlags.SF = (al>>7)&1;
                        _currentThread->cpuFlags.ZF = al == 0;
                    }
                        break;
                    case 0xd5: {
                        //aad
                        assert(modrm == 0xa);
                        /*
                         tempAL ← AL;
                         tempAH ← AH;
                         AL ← (tempAL + (tempAH ∗ imm8)) AND FFH; (* imm8 is set to 0AH for the AAD mnemonic.*) 
                         AH ← 0;
                         */
                        uint8_t al = fe_threadContext_register8(_currentThread, kAL);
                        uint8_t ah = fe_threadContext_register8(_currentThread, kAH);
                        fe_threadContext_setRegister8(_currentThread, kAL, (al + (ah*0xa))&0xff);
                        fe_threadContext_setRegister8(_currentThread, kAH, 0);

                        
                        al = fe_threadContext_register8(_currentThread, kAL);

                        fe_cpuflags_fillParityFromByte(&_currentThread->cpuFlags, al);
                        _currentThread->cpuFlags.SF = (al>>7)&1;
                        _currentThread->cpuFlags.ZF = al == 0;
                    }
                        break;
                    case 0xe3: {
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgSize == 32);
                        
                        if(_currentThread->ecx == 0) {
                        
                            _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                            beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                        
                            continue;
                        }
                    }
                        break;
                    case 0xe9:
                    case 0xeb: { //jmpl to 32bit addr
                        //assert(strcmp(op->Instruction.Mnemonic,"jmp ")==0);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgSize == 32);
                        
                        _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                        beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                        
                        continue;
                    }
                        break;
                    case 0xe8: { //calll 32bit relative
                        //assert(strcmp(op->Instruction.Mnemonic,"call ")==0);
                        assert(op->Argument1.ArgType & RELATIVE_);
                        assert(op->Argument1.ArgType & CONSTANT_TYPE);
                        assert(op->Argument1.ArgSize == 32);
                        
                        uint32_t eip = _currentThread->eip;
                        eip += len;
                        
                        fe_stack_push32(_currentThread->stack, eip);
                        
                        _currentThread->eip = (uint32_t)op->Instruction.AddrValue;
                        beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
                        
                        continue;
                    }
                        break;
                    case 0xf5: {
                        _currentThread->cpuFlags.CF = _currentThread->cpuFlags.CF == 0 ? 1 : 0;
                    }
                        break;
                    case 0xf6: {
                        instruction_f6(&op, _processContext);
                    }
                        break;
                    case 0xf7: {
                        instruction_f7(&op, _processContext);
                    }
                        break;
                        
                    case 0xff: {
                        BOOL shouldCountinue = NO;
                        instruction_ff(&op, &modrm, &len, self, &shouldCountinue);
                        
                        if(shouldCountinue) {
                            continue;
                        }
                    }
                        break;
                    case 0xf40: {
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.OF == 1) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf44: {
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.ZF == 1) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf45: {
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.ZF == 0) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                        
                    }
                        break;
                    case 0xf4c: {
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.SF != _currentThread->cpuFlags.OF) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf4e: {
                        //ZF=1 or SF≠ OF
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.ZF == 1 || (_currentThread->cpuFlags.SF != _currentThread->cpuFlags.OF)) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf4d: {
                        //SF=OF
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.SF == _currentThread->cpuFlags.OF) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf4f: {
                        //ZF=0 and SF=OF
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.ZF==0 && (_currentThread->cpuFlags.SF == _currentThread->cpuFlags.OF)) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf42: {
                        //CF=1
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.CF==1) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf41: {

                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.OF==0) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf43: {
                        //CF=0
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.CF==0) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf4a: {
                        //PF=1
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.PF==1) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf4b: {
                        //PF=0
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.PF==0) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf46: {
                        //CF=1 or ZF=1
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.CF==1 || _currentThread->cpuFlags.ZF==1) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf47: {
                        //CF=0 and ZF=0
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.CF==0 && _currentThread->cpuFlags.ZF==0) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf48: {

                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.SF==1) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    case 0xf49: {
                        
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        
                        if(_currentThread->cpuFlags.SF==0) {
                            beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                        }
                    }
                        break;
                    
                        /*
                         
                         0F 9D	SETGE r/m8	Set byte if greater or equal (SF=OF).
                         0F 9C	SETL r/m8	Set byte if less (SF<>OF).
                         0F 9E	SETLE r/m8	Set byte if less or equal (ZF=1 or SF<>OF).
                         0F 96	SETNA r/m8	Set byte if not above (CF=1 or ZF=1).
                         0F 92	SETNAE r/m8	Set byte if not above or equal (CF=1).
                         0F 93	SETNB r/m8	Set byte if not below (CF=0).
                         0F 97	SETNBE r/m8	Set byte if not below or equal (CF=0 and ZF=0).
                         0F 93	SETNC r/m8	Set byte if not carry (CF=0).
                         
                         0F 9E	SETNG r/m8	Set byte if not greater (ZF=1 or SF<>OF).
                         0F 9C	SETNGE r/m8	Set if not greater or equal (SF<>OF).
                         0F 9D	SETNL r/m8	Set byte if not less (SF=OF).
                         
                         0F 91	SETNO r/m8	Set byte if not overflow (OF=0).
                         0F 9B	SETNP r/m8	Set byte if not parity (PF=0).
                         0F 99	SETNS r/m8	Set byte if not sign (SF=0).
                         
                         0F 90	SETO r/m8	Set byte if overflow (OF=1).
                         0F 9A	SETP r/m8	Set byte if parity (PF=1).
                         0F 9A	SETPE r/m8	Set byte if parity even (PF=1).
                         0F 9B	SETPO r/m8	Set byte if parity odd (PF=0).
                         0F 98	SETS r/m8	Set byte if sign (SF=1).
                         */
                    case 0xf97: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.CF == 0 && _currentThread->cpuFlags.ZF == 0, _processContext);
                    }
                        break;
                    case 0xf90: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.OF == 1, _processContext);
                    }
                        break;
                    case 0xf99: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.SF == 0, _processContext);
                    }
                        break;
                    case 0xf98: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.SF == 1, _processContext);
                    }
                        break;
                    case 0xf91: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.OF == 0, _processContext);
                    }
                        break;
                    case 0xf93: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.CF == 0, _processContext);
                    }
                        break;
                    case 0xf92: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.CF == 1, _processContext);
                    }
                        break;
                    case 0xf96: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.CF == 1 || _currentThread->cpuFlags.ZF == 1, _processContext);
                    }
                        break;
                    case 0xf94: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.ZF == 1, _processContext);
                    }
                        break;
                    case 0xf9f: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.ZF == 0 && _currentThread->cpuFlags.SF == _currentThread->cpuFlags.OF, _processContext);
                    }
                        break;
                    case 0xf95: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.ZF == 0, _processContext);
                    }
                        break;
                    case 0xf9a: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.PF==1, _processContext);
                    }
                        break;
                    case 0xf9b: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.PF==0, _processContext);
                    }
                        break;
                    case 0xf9c: {
                        beu_store_value_in_arg(&op->Argument1, _currentThread->cpuFlags.SF != _currentThread->cpuFlags.OF, _processContext);
                    }
                        break;
                    case 0xf9d: {
                        //Set byte if not less (SF=OF).
                        if(_currentThread->cpuFlags.SF == _currentThread->cpuFlags.OF) {
                            beu_store_value_in_arg(&op->Argument1, 1, _processContext);
                        } else {
                            beu_store_value_in_arg(&op->Argument1, 0, _processContext);
                        }
                    }
                        break;
                    case 0xf9e: {
                        //Set byte if not greater (ZF=1 or SF≠ OF)
                        if((_currentThread->cpuFlags.ZF==1) || (_currentThread->cpuFlags.SF != _currentThread->cpuFlags.OF)) {
                            beu_store_value_in_arg(&op->Argument1, 1, _processContext);
                        } else {
                            beu_store_value_in_arg(&op->Argument1, 0, _processContext);
                        }
                    }
                        break;
                    case 0xfaf: {
                        //imul
                        uint32_t arg1Value = beu_load_arg_value(&op->Argument1, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        uint64_t result = fe_threadContext_imul32(_currentThread, arg1Value, arg2Value, (FEBitWidth)op->Argument1.ArgSize);
                        beu_store_value_in_arg(&op->Argument1, (uint32_t)result, _processContext);
                    }
                        break;
                    case 0xfbe:
                    case 0xfbf: { //movsx
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        if(op->Argument2.ArgSize == 8) {
                            int8_t originalValue = (int8_t)arg2Value;
                            arg2Value = (int32_t)originalValue;
                        } else if(op->Argument2.ArgSize == 16) {
                            int16_t originalValue = arg2Value;
                            arg2Value = (int32_t)originalValue;
                        } else {
                            assert(false);
                        }
                        beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                    }
                        break;
                    case 0xfb6:
                    case 0xfb7: {// XXX
                        /*
                         0F	B6		r	03+					MOVZX	r16/32	r/m8									Move with Zero-Extend
                         0F	B7		r	03+					MOVZX	r16/32	r/m16									Move with Zero-Extend
                         */
                        uint32_t arg2Value = beu_load_arg_value(&op->Argument2, (uint32_t)op->Instruction.Immediat, _processContext);
                        //                uint32_t arg2S =
                        beu_store_value_in_arg(&op->Argument1, arg2Value, _processContext);
                    }
                        break;
                    case 0xfc: {
                        _currentThread->cpuFlags.DF = 0;
                    }
                        break;
                    case 0xfd: {
                        _currentThread->cpuFlags.DF = 1;
                    }
                        break;
                    case 0x9e: {
                        // XXX
                        //sahf
                        //EFLAGS(SF:ZF:0:AF:0:PF:1:CF) = AH;
                        uint8_t ah = fe_threadContext_register8(_currentThread, kAH);
                        _currentThread->cpuFlags.CF = ah&1;
                        _currentThread->cpuFlags.PF = (ah>>2)&1;
                        _currentThread->cpuFlags.AF = (ah>>4)&1;
                        _currentThread->cpuFlags.ZF = (ah>>6)&1;
                        _currentThread->cpuFlags.SF = (ah>>7)&1;
                    }
                        break;
                    case 0xc8: {//XXX need tests
                        //assert(strcmp(op->Instruction.Mnemonic,"enter ")==0);

                        /*
                         (Int64) *((UInt16*)(UIntPtr) (GV.EIP_+1)));
                         (Int64) *((UInt8*)(UIntPtr) (GV.EIP_+3)));
                         */
                        char *instruction_ptr = (char*)op->EIP;
                        uint16_t frame_size = *((uint16_t*)(instruction_ptr+1));
                        uint8_t  nest_level = *((uint8_t*)(instruction_ptr+3));
                        // assert(frame_size == 8);
                        assert(nest_level == 0);
                        nest_level = nest_level % 32;
                        /*
                         Push(EBP);
                         FrameTemp ← ESP; FI;
                         */
                        uint32_t ebp = _currentThread->ebp;
                        fe_stack_push32(_currentThread->stack, ebp);
                        uint32_t frame_temp = _currentThread->esp;
                        
                        if(nest_level != 0) {
                            for(uint32_t i = 1; i<nest_level; i++) {
                                /*
                                 EBP ← EBP - 4;
                                 Push([EBP]); (* Doubleword push *)
                                 */
                                ebp = _currentThread->ebp;
                                ebp -= 4;
                                _currentThread->ebp = ebp;
                                fe_stack_push32(_currentThread->stack, ebp);
                            }
                            //Push(FrameTemp);
                            fe_stack_push32(_currentThread->stack, frame_temp);
                        }
                        /*
                         EBP ← FrameTemp; 
                         ESP ← ESP − Size;
                         */
                        _currentThread->ebp = frame_temp;
                        uint32_t esp = _currentThread->esp;
                        _currentThread->esp = esp - frame_size;
                    }
                        break;
                    default: {
                        fprintf(stderr, "unknown instruction 0x%x\n", op->Instruction.Opcode);
                        assert(false);
                        exit(-1);
                    }
                        break;
                }
                
            } else if(op->Instruction.Category & FPU_INSTRUCTION) {
                switch (op->Instruction.Opcode) {
                    case 0xdb: {
                        instruction_fpu_db(&op, modrm, _processContext);
                    }
                        break;
                    case 0xd9: {
                        instruction_fpu_d9(&op, modrm, _processContext);
                    }
                        break;
                    case 0x9b: {
                        instruction_fpu_9b(&op, modrm, _processContext);
                    }
                        break;
                    case 0xd8: {
                        instruction_fpu_d8(&op, modrm, _processContext);
                    }
                        break;
                    case 0xdd: {
                        instruction_fpu_dd(&op, modrm, _processContext);
                    }
                        break;
                    case 0xde: {
                        instruction_fpu_de(&op, modrm, _processContext);
                    }
                        break;
                    case 0xdc: {
                        instruction_fpu_dc(&op, modrm, _processContext);
                    }
                        break;
                    case 0xdf: {
                        instruction_fpu_df(&op, modrm, _processContext);
                    }
                        break;
                        
                    default:
                        fprintf(stderr, "unknown instruction 0x%x\n", op->Instruction.Opcode);
                        assert(false);
                        exit(-1);
                        break;
                }
            } else {
                assert(false);
            }
        jump_to_next_instr: {
                uint32_t eip = (uint32_t)op->VirtualAddr;
                eip += len;
                _currentThread->eip = eip;
                
                beu_update_disasm_from_context(&op, &len, &modrm, _processContext);
            }
        }
    }
    
    if(_printStdOut) {
        printf("%s",[_stdoutBuffer cStringUsingEncoding: NSASCIIStringEncoding]);
    }
    
    return _exitCode;
}

- (void) exit:(uint32_t) code {
    _exit = YES;
    _exitCode = code;
}

- (NSString*) stdoutBuffer {
    return _stdoutBuffer.copy;
}

- (void) addToStdout:(NSString*) str {
    [_stdoutBuffer appendString: str];
}

void instruction_fpu_dc(DISASM **op, uint8_t modrm, FEProcessContext *process) {
    if (modrm <= 0xbf) {
        if ((*op)->Reserved_.REGOPCODE == 0) {
            //fadd
            //Add m64fp to ST(0) and store result in ST(0).
            long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(double_t) == 8);
            double_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,8);
            long double result = st0 + mValue;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
        }
        else if ((*op)->Reserved_.REGOPCODE == 1) {
            //fmul
            long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(double_t) == 8);
            double_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,8);
            long double result = st0Value * mValue;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
            
        }
        else if ((*op)->Reserved_.REGOPCODE == 2 || (*op)->Reserved_.REGOPCODE == 3) {
            //fcom
            //Compare ST(0) with m64fp.
            //fcomp
            //FCOMP m64fp	Compare ST(0) with m64fp and pop register stack.
            /*
             
             FCOM/FCOMP/FCOMPP Results
             Condition	    C3	C2	C0
             ST(0) > Source	0	0	0
             ST(0) < Source	0	0	1
             ST(0) = Source	1	0	0
             */
            long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
            
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(double_t) == 8);
            double_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,8);
            
            fe_fpu_clearFlag(process->currentThread->fpu, kC1);

            if(st0Value > mValue) {
                fe_fpu_clearFlag(process->currentThread->fpu, kC0);
                fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                fe_fpu_clearFlag(process->currentThread->fpu, kC3);
            } else if(st0Value < mValue) {
                fe_fpu_setFlag(process->currentThread->fpu, kC0);
                fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                fe_fpu_clearFlag(process->currentThread->fpu, kC3);
            } else {
                fe_fpu_clearFlag(process->currentThread->fpu, kC0);
                fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                fe_fpu_setFlag(process->currentThread->fpu, kC3);
            }
            if ((*op)->Reserved_.REGOPCODE == 3) {
                fe_fpu_incrementTop(process->currentThread->fpu);
            }
        }
        else if ((*op)->Reserved_.REGOPCODE == 4) {
            //fsub
            float_t st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(double_t) == 8);
            double_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,8);
            long double result = st0Value - mValue;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
        }
        else if ((*op)->Reserved_.REGOPCODE == 5) {
            assert(false);//fsubr
        }
        else if ((*op)->Reserved_.REGOPCODE == 6) {
            //fdiv
            //Divide ST(0) by m64fp and store result in ST(0).
            long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(double_t) == 8);
            double_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,8);
            long double result = st0/mValue;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);

        }
        else if ((*op)->Reserved_.REGOPCODE == 7) {
            //fdivr
            //Divide m64fp by ST(0) and store result in ST(0)
            long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(double_t) == 8);
            double_t mvalue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mvalue,address,8);
            long double result = ((long double)mvalue) / st0;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
        }
        else {
            assert(false);
        }
    }
    else {
        if ((modrm & 0xf0) == 0xc0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fadd
            }
            else {
                assert(false);//fmul
            }
        }
        else if ((modrm & 0xf0) == 0xd0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fcom2
            }
            else {
                assert(false);//fcomp3
            }
        }
        else if ((modrm & 0xf0) == 0xe0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fsubr
            }
            else {
                //fsub
                //Subtract ST(0) from ST(i) and store result in ST(i).
                FEFPURegisterName regName = beu_fpu_register_from_argtype((*op)->Argument1.ArgType);
                long double arg1Value = fe_fpu_register(process->currentThread->fpu, regName);
                long double arg2Value = fe_fpu_register(process->currentThread->fpu, kST0);
                long double result = arg1Value - arg2Value;
                fe_fpu_setRegister(process->currentThread->fpu, regName, result);
            }
        }
        else if ((modrm & 0xf0) == 0xf0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fdivr
            }
            else {
                assert(false);//fdiv
            }
        }
        else {
            assert(false);
        }
    }
}

void instruction_fpu_d8(DISASM **op, uint8_t modrm, FEProcessContext *process) {
    if (modrm <= 0xbf) {
        if ((*op)->Reserved_.REGOPCODE == 0) {
            //fadd
            float_t st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(float_t) == 4);
            float_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,4);
            long double result = st0Value + mValue;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
        }
        else if ((*op)->Reserved_.REGOPCODE == 1) {
            //fmul
            //Multiply ST(0) by m32fp and store result in ST(0)
            long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(float_t) == 4);
            float_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,4);
            long double result = st0Value * mValue;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
        }
        else if ((*op)->Reserved_.REGOPCODE == 2) {
            assert(false);//fcom
        }
        else if ((*op)->Reserved_.REGOPCODE == 3) {
            assert(false);//fcomp
        }
        else if ((*op)->Reserved_.REGOPCODE == 4) {
            float_t st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(float_t) == 4);
            float_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,4);
            long double result = st0Value - mValue;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
        }
        else if ((*op)->Reserved_.REGOPCODE == 5) {
            assert(false);//fsubr
        }
        else if ((*op)->Reserved_.REGOPCODE == 6) {
            float_t st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            assert(sizeof(float_t) == 4);
            float_t mValue;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&mValue,address,4);
            long double result = st0Value / mValue;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
        }
        else if ((*op)->Reserved_.REGOPCODE == 7) {
            assert(false);//fdivr
        }
        else {
            assert(false);
        }
    }
    else {
        if ((modrm & 0xf0) == 0xc0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fadd
            }
            else {
                //fmul
                //FMUL ST(0), ST(i) and store result in ST(0)
                FEFPURegisterName arg2RegName = beu_fpu_register_from_argtype((*op)->Argument2.ArgType);
                long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1Value = fe_fpu_register(process->currentThread->fpu, arg2RegName);
                
                fe_fpu_setRegister(process->currentThread->fpu, kST0, st0Value * st1Value);
            }
        }
        else if ((modrm & 0xf0) == 0xd0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fcom
            }
            else {
                //fcomp
                //D8 D8+i	FCOMP ST(i)	Compare ST(0) with ST(i) and pop register stack.
                /*
                 
                 FCOM/FCOMP/FCOMPP Results
                 Condition	    C3	C2	C0
                 ST(0) > Source	0	0	0
                 ST(0) < Source	0	0	1
                 ST(0) = Source	1	0	0
                 */
                FEFPURegisterName arg2RegName = beu_fpu_register_from_argtype((*op)->Argument2.ArgType);
                long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1Value = fe_fpu_register(process->currentThread->fpu, arg2RegName);
                fe_fpu_clearFlag(process->currentThread->fpu, kC1);
                if(st0Value > st1Value) {
                    fe_fpu_clearFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC3);
                } else if(st0Value < st1Value) {
                    fe_fpu_setFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC3);
                } else {
                    fe_fpu_clearFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_setFlag(process->currentThread->fpu, kC3);
                }
                fe_fpu_incrementTop(process->currentThread->fpu);
            }
        }
        else if ((modrm & 0xf0) == 0xe0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                //fsub
                //Subtract ST(i) from ST(0) and store result in ST(0).
                FEFPURegisterName arg2RegName = beu_fpu_register_from_argtype((*op)->Argument1.ArgType);
                long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
                long double sti = fe_fpu_register(process->currentThread->fpu, arg2RegName);
                long double result = st0 - sti;
                fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
            }
            else {
                assert(false);//fsubr
            }
        }
        else if ((modrm & 0xf0) == 0xf0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                //fdiv
                FEFPURegisterName arg2RegName = beu_fpu_register_from_argtype((*op)->Argument2.ArgType);
                long double arg1Value = fe_fpu_register(process->currentThread->fpu, kST0);
                long double arg2Value = fe_fpu_register(process->currentThread->fpu, arg2RegName);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, arg1Value/arg2Value);
            }
            else {
                assert(false);//fdivr
            }
        } else {
            assert(false);
        }
    }
}

void instruction_fpu_df(DISASM **op, uint8_t modrm, FEProcessContext *process) {
    if (modrm <= 0xbf) {
        if ((*op)->Reserved_.REGOPCODE == 0) {
            assert(false);//fild
        }
        else if ((*op)->Reserved_.REGOPCODE == 1) {
            assert(false);//fisttp
        }
        else if ((*op)->Reserved_.REGOPCODE == 2) {
            assert(false);//fist
        }
        else if ((*op)->Reserved_.REGOPCODE == 3) {
            assert(false);//fistp
        }
        else if ((*op)->Reserved_.REGOPCODE == 4) {
            assert(false);//fbld
        }
        else if ((*op)->Reserved_.REGOPCODE == 5) {
            //fild
            //Push m64int onto the FPU register stack.
            fe_fpu_decrementTop(process->currentThread->fpu);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            uint64_t value;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&value,address,8);
            fe_fpu_setRegister(process->currentThread->fpu, kST0, value);
        }
        else if ((*op)->Reserved_.REGOPCODE == 6) {
            assert(false);//fbstp
        }
        else if ((*op)->Reserved_.REGOPCODE == 7) {
            //fistp
            //Store ST(0) in m64int and pop register stack.
            long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
            uint64_t value = st0;
            uint32_t address = beu_address_from_argtype(&(*op)->Argument1, process);
            assert(sizeof(value) == (*op)->Argument1.ArgSize/8);
            fe_memoryMap_memcpyToVirtualFromReal(process->memory, address, &value, sizeof(value));
            
            fe_fpu_setTag(process->currentThread->fpu, kST0, kEmpty);
            fe_fpu_incrementTop(process->currentThread->fpu);
            //xxx
        }
        else {
            assert(false);
        }
    }
    else {
        if ((modrm & 0xf0) == 0xc0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//ffreep
            }
            else {
                assert(false);//fxch7
            }
        }
        else if ((modrm & 0xf0) == 0xd0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fstp8
            }
            else {
                assert(false);//fstp9
            }
        }
        else if ((modrm & 0xf0) == 0xe0) {
            if (modrm == 0xe0) {
                //fstsw
                fe_threadContext_setRegister16(process->currentThread, kAX, process->currentThread->fpu->statusWord);
            }
            else if ((modrm & 0xf) >=8) {
                assert(false);//fucomip
            }
            
            
            else {
                assert(false);
            }
        }
        
        else if ((modrm & 0xf0) == 0xf0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fcomip
            }
            else {
                assert(false);
            }
        }
        else {
            assert(false);
        }
    }
}

void instruction_fpu_dd(DISASM **op, uint8_t modrm, FEProcessContext *process) {
    if (modrm <= 0xbf) {
        if ((*op)->Reserved_.REGOPCODE == 0) {
            //fld
            fe_fpu_decrementTop(process->currentThread->fpu);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            double_t value;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&value,address,8);
            fe_fpu_setRegister(process->currentThread->fpu, kST0, value);
        }
        else if ((*op)->Reserved_.REGOPCODE == 1) {
            assert(false);//fisttp
        }
        else if ((*op)->Reserved_.REGOPCODE == 2) {
            //fst
            assert(sizeof(double_t) == 8);
            double_t st0 = fe_fpu_register(process->currentThread->fpu, kST0);
            
            uint32_t address = beu_address_from_argtype(&(*op)->Argument1, process);
            
            fe_memoryMap_memcpyToVirtualFromReal(process->memory,address,&st0,sizeof(st0));
            //xxx
        }
        else if ((*op)->Reserved_.REGOPCODE == 3) {
            //fstp
            assert(sizeof(double_t) == 8);
            double_t st0 = fe_fpu_register(process->currentThread->fpu, kST0);
            
            uint32_t address = beu_address_from_argtype(&(*op)->Argument1, process);
            
            fe_memoryMap_memcpyToVirtualFromReal(process->memory,address,&st0,sizeof(st0));
            
            fe_fpu_setTag(process->currentThread->fpu, kST0, kEmpty);
            fe_fpu_incrementTop(process->currentThread->fpu);
        }
        else if ((*op)->Reserved_.REGOPCODE == 4) {
            assert(false);//frstor
        }
        else if ((*op)->Reserved_.REGOPCODE == 6) {
            assert(false);//fsave
        }
        else if ((*op)->Reserved_.REGOPCODE == 7) {
            //fstsw
            beu_store_value_in_arg(&(*op)->Argument1, process->currentThread->fpu->statusWord, process);
            //xxx
        }
        else {
            assert(false);
        }
    }
    else {
        if ((modrm & 0xf0) == 0xc0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//ffree
            }
            else {
                assert(false);//fxch4
            }
        }
        else if ((modrm & 0xf0) == 0xd0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fst
            }
            else {
                //fstp
                FEFPURegisterName registerName = beu_fpu_register_from_argtype((*op)->Argument1.ArgType);
                long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
                fe_fpu_setRegister(process->currentThread->fpu, registerName, st0);
                
                fe_fpu_setTag(process->currentThread->fpu, kST0, kEmpty);
                fe_fpu_incrementTop(process->currentThread->fpu);
            }
        }
        else if ((modrm & 0xf0) == 0xe0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fucom
            }
            else {
                assert(false);//fucomp
            }
            
        }
        
        else {
            assert(false);
        }
    }
}

void instruction_fpu_de(DISASM **op, uint8_t modrm, FEProcessContext *process) {
    if (modrm <= 0xbf) {
        if ((*op)->Reserved_.REGOPCODE == 0) {
            assert(false);//fiadd
        }
        else if ((*op)->Reserved_.REGOPCODE == 1) {
            assert(false);//fimul
        }
        else if ((*op)->Reserved_.REGOPCODE == 2) {
            assert(false);//ficom
        }
        else if ((*op)->Reserved_.REGOPCODE == 3) {
            assert(false);//ficomp
        }
        else if ((*op)->Reserved_.REGOPCODE == 4) {
            assert(false);//fisub
        }
        else if ((*op)->Reserved_.REGOPCODE == 5) {
            assert(false);//fisubr
        }
        else if ((*op)->Reserved_.REGOPCODE == 6) {
            assert(false);//fidiv
        }
        else if ((*op)->Reserved_.REGOPCODE == 7) {
            assert(false);//fidivr
        }
        else {
            assert(false);
        }
    }
    else {
        if ((modrm & 0xf0) == 0xc0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                //faddp
                //FADDP ST(i), ST(0)	Add ST(0) to ST(i), store result in ST(i), and pop the register stack.
                FEFPURegisterName arg1RegName = beu_fpu_register_from_argtype((*op)->Argument1.ArgType);
                long double sti = fe_fpu_register(process->currentThread->fpu, arg1RegName);
                long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
                long double result = sti + st0;
                fe_fpu_setRegister(process->currentThread->fpu, arg1RegName, result);
                fe_fpu_incrementTop(process->currentThread->fpu);
            }
            else {
                //fmulp
                //Multiply ST(1) by ST(0), store result in ST(1), and pop the register stack
                long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1Value = fe_fpu_register(process->currentThread->fpu, kST1);
                fe_fpu_setRegister(process->currentThread->fpu, kST1, st0Value * st1Value);

                fe_fpu_incrementTop(process->currentThread->fpu);
            }
        }
        else if ((modrm & 0xf0) == 0xd0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fcomp5
            }
            else if (modrm == 0xd9){
                //fcompp
                /*
                 
                 FCOM/FCOMP/FCOMPP Results
                 Condition	    C3	C2	C0
                 ST(0) > Source	0	0	0
                 ST(0) < Source	0	0	1
                 ST(0) = Source	1	0	0
                 */
                long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1Value = fe_fpu_register(process->currentThread->fpu, kST1);
                fe_fpu_clearFlag(process->currentThread->fpu, kC1);
                if(st0Value > st1Value) {
                    fe_fpu_clearFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC3);
                } else if(st0Value < st1Value) {
                    fe_fpu_setFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC3);
                } else {
                    fe_fpu_clearFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_setFlag(process->currentThread->fpu, kC3);
                }
                fe_fpu_incrementTop(process->currentThread->fpu);
                fe_fpu_incrementTop(process->currentThread->fpu);
            }
            else {
                assert(false);
            }
        }
        else if ((modrm & 0xf0) == 0xe0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fsubrp
            }
            else {
                //fsubp
                //Subtract ST(0) from ST(1), store result in ST(1), and pop register stack.
                long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1Value = fe_fpu_register(process->currentThread->fpu, kST1);
                fe_fpu_setRegister(process->currentThread->fpu, kST1, st1Value - st0Value);

                fe_fpu_incrementTop(process->currentThread->fpu);
            }
        }
        else if ((modrm & 0xf0) == 0xf0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fdivrp
            }
            else {
                //fdivp
                FEFPURegisterName arg1RegName = beu_fpu_register_from_argtype((*op)->Argument1.ArgType);
                long double arg1Value = fe_fpu_register(process->currentThread->fpu, arg1RegName);
                long double arg2Value = fe_fpu_register(process->currentThread->fpu, kST0);
                /*
                 The FDIVP instructions perform the additional operation of popping the FPU register stack after storing the result. To pop the register stack, the processor marks the ST(0) register as empty and increments the stack pointer (TOP) by 1. The no-operand version of the floating-point divide instructions always results in the register stack being popped. In some assemblers, the mnemonic for this instruction is FDIV rather than FDIVP.
                 */
                fe_fpu_setRegister(process->currentThread->fpu, arg1RegName, arg1Value/arg2Value);
                
                fe_fpu_setTag(process->currentThread->fpu, kST0, kEmpty);
                fe_fpu_incrementTop(process->currentThread->fpu);
            }
        }
        else {
            assert(false);
        }
    }
}

void instruction_fpu_9b(DISASM **op, uint8_t modrm, FEProcessContext *process) {
    // xxx WAIT/FWAIT. do nothing
}

void instruction_fpu_d9(DISASM **op, uint8_t modrm, FEProcessContext *process) {
    
    
    if (modrm <= 0xbf) {

        if ((*op)->Reserved_.REGOPCODE == 0) {
            //fld
            fe_fpu_decrementTop(process->currentThread->fpu);
            uint32_t address = beu_address_from_argtype(&(*op)->Argument2, process);
            float_t value;
            fe_memoryMap_memcpyToRealFromVirtual(process->memory,&value,address,4);
            fe_fpu_setRegister(process->currentThread->fpu, kST0, value);
        }
        else if ((*op)->Reserved_.REGOPCODE == 2) {
            //fst
            assert(sizeof(float_t) == 4);
            float_t st0 = fe_fpu_register(process->currentThread->fpu, kST0);
            
            uint32_t address = beu_address_from_argtype(&(*op)->Argument1, process);
            
            fe_memoryMap_memcpyToVirtualFromReal(process->memory,address,&st0,sizeof(st0));
        }
        else if ((*op)->Reserved_.REGOPCODE == 3) {
            assert(false);//fstp
        }
        else if ((*op)->Reserved_.REGOPCODE == 4) {
            assert(false);//fldenv
        }
        else if ((*op)->Reserved_.REGOPCODE == 5) {
            //fldcw
            assert((*op)->Argument2.ArgSize==16);
            uint32_t value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
            process->currentThread->fpu->controlWord = value;
        }
        else if ((*op)->Reserved_.REGOPCODE == 6) {
            assert(false);//fstenv
        }
        else if ((*op)->Reserved_.REGOPCODE == 7) {
            assert((*op)->Argument1.ArgSize == 16);
            beu_store_value_in_arg(&(*op)->Argument1, process->currentThread->fpu->controlWord, process);
        }
        else {
            assert(false);
        }
    }
    else {
        if ((modrm & 0xf0) == 0xc0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                //fld
                FEFPURegisterName registerName = beu_fpu_register_from_argtype((*op)->Argument1.ArgType);
                long double value = fe_fpu_register(process->currentThread->fpu, registerName);
                fe_fpu_decrementTop(process->currentThread->fpu);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, value);
            }
            else {
                //fxch
                long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1 = fe_fpu_register(process->currentThread->fpu, kST1);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, st1);
                fe_fpu_setRegister(process->currentThread->fpu, kST1, st0);
            }
        }
        else if ((modrm & 0xf0) == 0xd0) {
            if ((modrm & 0xf) ==0) {
                assert(false);//fnop
            }
            else if (((modrm & 0xf) >=0x8) && ((modrm & 0xf) <=0xf)) {
                assert(false);//fstp1
            }
            else {
                assert(false);
            }
            
        }
        else if ((modrm & 0xf0) == 0xe0) {
            if ((modrm & 0xf) ==0) {
                //fchs
                long double value = fe_fpu_register(process->currentThread->fpu, kST0);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, -value);
            }
            else if ((modrm & 0xf) ==1) {
                //fabs
                long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, fabsl(st0Value));
            }
            else if ((modrm & 0xf) ==4) {
                //ftst
                long double st0Value = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1Value = 0.0;
                fe_fpu_clearFlag(process->currentThread->fpu, kC1);
                if(st0Value > st1Value) {
                    fe_fpu_clearFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC3);
                } else if(st0Value < st1Value) {
                    fe_fpu_setFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC3);
                } else {
                    fe_fpu_clearFlag(process->currentThread->fpu, kC0);
                    fe_fpu_clearFlag(process->currentThread->fpu, kC2);
                    fe_fpu_setFlag(process->currentThread->fpu, kC3);
                }
                // XXX compare class of numbers

            }
            else if ((modrm & 0xf) ==5) {
                assert(false);//fxam
            }
            else if ((modrm & 0xf) ==8) {
                //fld1
                fe_fpu_decrementTop(process->currentThread->fpu);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, 1.0);
            }
            else if ((modrm & 0xf) ==9) {
                assert(false);//fldl2t
            }
            else if ((modrm & 0xf) ==0xa) {
#if 0
#define M_E         2.71828182845904523536028747135266250   /* e              */
#define M_LOG2E     1.44269504088896340735992468100189214   /* log2(e)        */
#define M_LOG10E    0.434294481903251827651128918916605082  /* log10(e)       */
#define M_LN2       0.693147180559945309417232121458176568  /* loge(2)        */
#define M_LN10      2.30258509299404568401799145468436421   /* loge(10)       */
#define M_PI        3.14159265358979323846264338327950288   /* pi             */
#define M_PI_2      1.57079632679489661923132169163975144   /* pi/2           */
#define M_PI_4      0.785398163397448309615660845819875721  /* pi/4           */
#define M_1_PI      0.318309886183790671537767526745028724  /* 1/pi           */
#define M_2_PI      0.636619772367581343075535053490057448  /* 2/pi           */
#define M_2_SQRTPI  1.12837916709551257389615890312154517   /* 2/sqrt(pi)     */
#define M_SQRT2     1.41421356237309504880168872420969808   /* sqrt(2)        */
#define M_SQRT1_2   0.707106781186547524400844362104849039  /* 1/sqrt(2)      */
#endif
                //fldl2e
                //Push log_2(e) onto the FPU register stack.
                fe_fpu_decrementTop(process->currentThread->fpu);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, M_LOG2E);
            }
            else if ((modrm & 0xf) ==0xb) {
                assert(false);//fldpi
            }
            else if ((modrm & 0xf) ==0xc) {
                assert(false);//fldlg2
            }
            
            else if ((modrm & 0xf) ==0xd) {
                //fldln2
                fe_fpu_decrementTop(process->currentThread->fpu);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, M_LN2);
            }
            else if ((modrm & 0xf) ==0xe) {
                //fldz
                fe_fpu_decrementTop(process->currentThread->fpu);
                fe_fpu_setRegister(process->currentThread->fpu, kST0, 0.0);
            }
            
            else {
                assert(false);
            }
        }
        else if ((modrm & 0xf0) == 0xf0) {
            if ((modrm & 0xf) ==0) {
                //f2xm1
                //ST0 = (2^ST0 - 1);
                long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
                st0 = powl(2, st0) - 1;
                fe_fpu_setRegister(process->currentThread->fpu, kST0, st0);
            }
            else if ((modrm & 0xf) ==1) {
                //fyl2x
                //Replace ST(1) with (ST(1) * log_2(ST(0))) and pop the register stack.
                long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1 = fe_fpu_register(process->currentThread->fpu, kST1);
                
                st1 = st1 * log2l(st0);
                
                fe_fpu_setRegister(process->currentThread->fpu, kST1, st1);
            }
            else if ((modrm & 0xf) ==2) {
                assert(false);//fptan
            }
            else if ((modrm & 0xf) ==3) {
                assert(false);//fpatan
            }
            else if ((modrm & 0xf) ==4) {
                assert(false);//fxtract
            }
            else if ((modrm & 0xf) ==5) {
                assert(false);//fprem1
            }
            else if ((modrm & 0xf) ==6) {
                assert(false);//fdecstp
            }
            else if ((modrm & 0xf) ==7) {
                assert(false);//fincstp
            }
            else if ((modrm & 0xf) ==8) {
                assert(false);//fprem
            }
            else if ((modrm & 0xf) ==9) {
                assert(false);//fyl2xp1
            }
            else if ((modrm & 0xf) ==0xa) {
                assert(false);//fsqrt
            }
            else if ((modrm & 0xf) ==0xb) {
                assert(false);//fsincos
            }
            else if ((modrm & 0xf) ==0xc) {
                //frndint
                long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
                st0 = (uint64_t)st0;
                fe_fpu_setRegister(process->currentThread->fpu, kST0, st0);
            }
            else if ((modrm & 0xf) ==0xd) {
                //fscale
                //ST(0) ← ST(0) ∗ 2RoundTowardZero(ST(1));
                long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
                long double st1 = fe_fpu_register(process->currentThread->fpu, kST1);
                long double result = st0 * powl(2,truncl(st1));
                fe_fpu_setRegister(process->currentThread->fpu, kST0, result);
            }
            else if ((modrm & 0xf) ==0xe) {
                assert(false);//fsin
            }
            else if ((modrm & 0xf) ==0xf) {
                assert(false);//fcos
            }
            else {
                assert(false);
            }
        }
    }
}

void instruction_fpu_db(DISASM **op, uint8_t modrm, FEProcessContext *process) {
    if (modrm <= 0xbf) {
        if ((*op)->Reserved_.REGOPCODE == 0) {
            //fild
            fe_fpu_decrementTop(process->currentThread->fpu);
            uint32_t value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
            long double st0 = value;
            fe_fpu_setRegister(process->currentThread->fpu, kST0, st0);
        }
        else if ((*op)->Reserved_.REGOPCODE == 1) {
            assert(false);//fisttp
        }
        else if ((*op)->Reserved_.REGOPCODE == 2) {
            assert(false);//fist
        }
        else if ((*op)->Reserved_.REGOPCODE == 3) {
            //fistp
            
            long double st0 = fe_fpu_register(process->currentThread->fpu, kST0);
            uint32_t value = st0;
            beu_store_value_in_arg(&(*op)->Argument1, value, process);
            
            fe_fpu_setTag(process->currentThread->fpu, kST0, kEmpty);
            fe_fpu_incrementTop(process->currentThread->fpu);
            //xxx
        }
        else if ((*op)->Reserved_.REGOPCODE == 5) {
            assert(false);//fld
        }
        else if ((*op)->Reserved_.REGOPCODE == 7) {
            assert(false);//fstp
        }
        else {
            assert(false);
        }
    }
    else {
        if ((modrm & 0xf0) == 0xc0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fcmovnb
            }
            else {
                assert(false);//fcmovne
            }
        }
        else if ((modrm & 0xf0) == 0xd0) {
            if (((modrm & 0xf) >=0) && ((modrm & 0xf) <=7)) {
                assert(false);//fcmovnbe
            }
            else {
                assert(false);//fcmovnu
            }
        }
        else if ((modrm & 0xf0) == 0xe0) {
            
            if ((modrm & 0xf) ==0) {
                assert(false);//fneni
            }
            else if ((modrm & 0xf) ==1) {
                assert(false);//fndisi
            }
            else if ((modrm & 0xf) ==2) {
                assert(false);//fnclex
            }
            else if ((modrm & 0xf) ==3) {
                fe_fpu_fninit(process->currentThread->fpu);
            }
            else if ((modrm & 0xf) ==4) {
                assert(false);//fnsetpm
            }
            else if ((modrm & 0xf) ==5) {
                assert(false);//frstpm
            }
            else if (((modrm & 0xf) >=0x8) && ((modrm & 0xf) <=0xf)) {
                assert(false);//fucomi
            }
            else {
                assert(false);
            }
        }
        else if ((modrm & 0xf0) == 0xf0) {
            if (((modrm & 0xf) >=0x0) && ((modrm & 0xf) <=0x7)) {
                assert(false);//fcomi
            }
            else {
                assert(false);
            }
        }
        else {
            assert(false);
        }
    }
}

/*
 FF		0						INC	r/m16/32						o..szap.	o..szap.			Increment by 1
 FF		1						DEC	r/m16/32						o..szap.	o..szap.			Decrement by 1
 FF		2						CALL	r/m16/32										Call Procedure
 FF		3						CALLF	m16:16/32										Call Procedure
 FF		4						JMP	r/m16/32										Jump
 FF		5						JMPF	m16:16/32										Jump
 FF		6						PUSH	r/m16/32										Push Word, Doubleword or Quadword Onto the Stack
 */
void instruction_ff(DISASM **op, uint8_t *modrm, int *len, FEProcess *process, BOOL *should_continue) {
    @autoreleasepool {
        assert(should_continue);
        *should_continue = NO;
        
        uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process->_processContext);
        if((*op)->Reserved_.REGOPCODE >=2 && (*op)->Reserved_.REGOPCODE <= 5) {
            if((*op)->Reserved_.REGOPCODE == 2 || (*op)->Reserved_.REGOPCODE == 3) {
                //call
                uint32_t eip = process.currentThread->eip;
                eip += *len;
                
                fe_stack_push32(process.currentThread->stack, eip);
            }
            
            if(process.importsProxy && [process.importsProxy isAddressWithinLoadedImports: arg1Value]) {
                if(process.logExternalCalls) {
                    NSString* funcDescription = [process.importsProxy functionDescriptionFromAddress: arg1Value];
                    printf("%lld(0x%X): calling %s\n",process->_instruction_counter,process.currentThread->eip, [funcDescription cStringUsingEncoding:NSASCIIStringEncoding]);
                }

                uint8_t argumentsSize = [process.importsProxy executeFunctionAtAddress: arg1Value
                                                                         withinProcess: process];
                
                uint32_t eip = fe_stack_pop32(process.currentThread->stack);
                process.currentThread->eip = eip;
                
                // cleaning up stack after call to imported function
                uint32_t esp = process.currentThread->esp;
                esp += argumentsSize;
                process.currentThread->esp = esp;
            } else {
                process.currentThread->eip = arg1Value;
            }
            beu_update_disasm_from_context(op, len, modrm, process->_processContext);
            *should_continue = YES;
        } else {
            switch((*op)->Reserved_.REGOPCODE) {
                case 0: { // inc
                    uint32_t result = fe_threadContext_inc(process.currentThread, arg1Value, (FEBitWidth)(*op)->Argument1.ArgSize);
                    beu_store_value_in_arg(&(*op)->Argument1, result, process->_processContext);
                }
                    break;
                case 1: { // dec
                    uint32_t result = fe_threadContext_dec(process.currentThread, arg1Value, (FEBitWidth)(*op)->Argument1.ArgSize);
                    beu_store_value_in_arg(&(*op)->Argument1, result, process->_processContext);
                }
                    break;
                case 6: { // push
                    uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process->_processContext);
                    fe_stack_push(process.currentThread->stack, arg2Value, (FEBitWidth)(*op)->Argument2.ArgSize);
                }
                    break;
            }
        }
    }
}

void instruction_80_81(DISASM **op, FEProcessContext *process) {
    /*
     81		0					L	ADD	r/m16/32	imm16/32					o..szapc	o..szapc			Add
     81		1					L	OR	r/m16/32	imm16/32					o..szapc	o..sz.pc	.....a..	o......c	Logical Inclusive OR
     81		2					L	ADC	r/m16/32	imm16/32				.......c	o..szapc	o..szapc			Add with Carry
     81		3					L	SBB	r/m16/32	imm16/32				.......c	o..szapc	o..szapc			Integer Subtraction with Borrow
     81		4					L	AND	r/m16/32	imm16/32					o..szapc	o..sz.pc	.....a..	o......c	Logical AND
     81		5					L	SUB	r/m16/32	imm16/32					o..szapc	o..szapc			Subtract
     81		6					L	XOR	r/m16/32	imm16/32					o..szapc	o..sz.pc	.....a..	o......c	Logical Exclusive OR
     81		7						CMP	r/m16/32	imm16/32					o..szapc	o..szapc			Compare Two Operands
     */
    assert((*op)->Argument1.ArgSize == (*op)->Argument2.ArgSize);
    FEBitWidth bitWidth = (FEBitWidth)(*op)->Argument1.ArgSize;
    uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
    uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
    
    switch((*op)->Reserved_.REGOPCODE) {
        case 0: {
            uint32_t result = fe_threadContext_add(process->currentThread, arg1Value, arg2Value, bitWidth);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 1: {
            uint32_t result = fe_threadContext_or(process->currentThread, arg1Value, arg2Value, bitWidth);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 2: {
            uint32_t result = fe_threadContext_adc(process->currentThread, arg1Value, arg2Value, bitWidth);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 3: {
            uint32_t result = fe_threadContext_sbb(process->currentThread, arg1Value, arg2Value, bitWidth);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 4: {
            uint32_t result = fe_threadContext_and(process->currentThread, arg1Value, arg2Value, bitWidth);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 5: {
            uint32_t result = fe_threadContext_sub(process->currentThread, arg1Value, arg2Value, bitWidth);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 6: {
            uint32_t result = fe_threadContext_xor(process->currentThread, arg1Value, arg2Value, bitWidth);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 7: {
            fe_threadContext_sub(process->currentThread, arg1Value, arg2Value, bitWidth);
        }
            break;
        default:
            assert(false);
    }

}

/*
 83		0					L	ADD	r/m16/32	imm8					o..szapc	o..szapc			Add
 83		1	03+				L	OR	r/m16/32	imm8					o..szapc	o..sz.pc	.....a..	o......c	Logical Inclusive OR
 83		2					L	ADC	r/m16/32	imm8				.......c	o..szapc	o..szapc			Add with Carry
 83		3					L	SBB	r/m16/32	imm8				.......c	o..szapc	o..szapc			Integer Subtraction with Borrow
 83		4	03+				L	AND	r/m16/32	imm8					o..szapc	o..sz.pc	.....a..	o......c	Logical AND
 83		5					L	SUB	r/m16/32	imm8					o..szapc	o..szapc			Subtract
 83		6	03+				L	XOR	r/m16/32	imm8					o..szapc	o..sz.pc	.....a..	o......c	Logical Exclusive OR
 83		7						CMP	r/m16/32	imm8					o..szapc	o..szapc			Compare Two Operands
 */
void instruction_83(DISASM **op, FEProcessContext *process) {
    
    FEBitWidth bitWidth = (FEBitWidth)(*op)->Argument1.ArgSize;
    
    uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
    uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
    //sign extend
    int8_t originalArg2Value = (int8_t)arg2Value;
    arg2Value = (int32_t)originalArg2Value;
    uint32_t result = 0;

    switch ((*op)->Reserved_.REGOPCODE) {
        case 0: {
            result = fe_threadContext_add(process->currentThread, arg1Value, arg2Value, bitWidth);
            goto save_result;
        }
            break;
        case 1: {
            result = fe_threadContext_or(process->currentThread, arg1Value, arg2Value, bitWidth);
            goto save_result;
        }
            break;
        case 2: {
            result = fe_threadContext_adc(process->currentThread, arg1Value, arg2Value, bitWidth);
            goto save_result;
        }
            break;
        case 3: {
            result = fe_threadContext_sbb(process->currentThread, arg1Value, arg2Value, bitWidth);
            goto save_result;
        }
            break;
        case 4: {
            result = fe_threadContext_and(process->currentThread, arg1Value, arg2Value, bitWidth);
            goto save_result;
        }
            break;
        case 5: {
            result = fe_threadContext_sub(process->currentThread, arg1Value, arg2Value, bitWidth);
            goto save_result;
        }
            break;
        case 6: {
            result = fe_threadContext_xor(process->currentThread, arg1Value, arg2Value, bitWidth);
            goto save_result;
        }
            break;
        case 7: {
            fe_threadContext_sub(process->currentThread, arg1Value, arg2Value, bitWidth);
            return;
        }
            break;
        default:
            assert(false);
            break;
    }
save_result:
    beu_store_value_in_arg(&(*op)->Argument1, result, process);
}

void instruction_f6(DISASM **op, FEProcessContext *process) {
    /*
     F6		0						TEST	r/m8	imm8					o..szapc	o..sz.pc	.....a..	o......c	Logical Compare
     F6		1		U12				TEST	r/m8	imm8					o..szapc	o..sz.pc	.....a..	o......c	Logical Compare
     F6		2						NOT	r/m8										One's Complement Negation
     F6		3						NEG	r/m8						o..szapc	o..szapc			Two's Complement Negation
     F6		4						MUL	AX	AL	r/m8				o..szapc	o......c	...szap.		Unsigned Multiply
     F6		5						IMUL	AX	AL	r/m8				o..szapc	o......c	...szap.		Signed Multiply
     F6		6						DIV	AL	AH	AX	r/m8			o..szapc		o..szapc		Unsigned Divide
     F6		7						IDIV	AL	AH	AX	r/m8			o..szapc		o..szapc		Signed Divide
     */
    switch((*op)->Reserved_.REGOPCODE) {
        case 0:
        case 1: {
            assert((*op)->Argument1.ArgSize == (*op)->Argument2.ArgSize);
            uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
            uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
            fe_threadContext_and(process->currentThread, arg1Value, arg2Value, (FEBitWidth)(*op)->Argument1.ArgSize);
        }
            break;
        case 2: {
            uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
            uint32_t result = fe_threadContext_not(process->currentThread, arg1Value, (FEBitWidth)(*op)->Argument1.ArgSize);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 3: {
            uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
            uint32_t result = fe_threadContext_neg(process->currentThread, arg1Value, (FEBitWidth)(*op)->Argument1.ArgSize);
            beu_store_value_in_arg(&(*op)->Argument1, result, process);
        }
            break;
        case 4: {
            assert((*op)->Argument1.ArgSize==8);
            
            uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
            uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
            uint64_t result = fe_threadContext_mul32(process->currentThread, arg1Value, arg2Value, (FEBitWidth)(*op)->Argument1.ArgSize);
            fe_threadContext_setRegister16(process->currentThread, kAX, (uint16_t)result);
        }
            break;
        case 5: {
            assert((*op)->Argument1.ArgSize==8);
            uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
            uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
            uint64_t result = fe_threadContext_imul32(process->currentThread, arg1Value, arg2Value, (FEBitWidth)(*op)->Argument1.ArgSize);
            fe_threadContext_setRegister16(process->currentThread, kAX, (uint16_t)result);
            return;
        }
            break;
        case 6: {
            assert((*op)->Argument2.ArgSize==8);
            uint32_t divident = fe_threadContext_register16(process->currentThread, kAX);
            uint32_t divider = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
            uint64_t remainder = 0;
            uint64_t quotient = fe_threadContext_div32(process->currentThread, divident, divider, (FEBitWidth)(*op)->Argument2.ArgSize, &remainder);
            
            fe_threadContext_setRegister8(process->currentThread, kAL, quotient);
            fe_threadContext_setRegister8(process->currentThread, kAH, remainder);

            return;
        }
            break;
        case 7: {
            assert((*op)->Argument2.ArgSize==8);
            int64_t arg1Value = beu_sign_extend(fe_threadContext_register16(process->currentThread, kAX), k16bit);
            int64_t divider = beu_sign_extend(beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process), k8bit);
            int64_t remainder = 0;
            int64_t quotient = fe_threadContext_idiv32(process->currentThread, arg1Value, divider, (FEBitWidth)(*op)->Argument2.ArgSize, &remainder);
        
            fe_threadContext_setRegister8(process->currentThread, kAL, quotient);
            fe_threadContext_setRegister8(process->currentThread, kAH, remainder);
            return;
        }
            break;
        default:
            assert(false);
    }
}

void instruction_f7(DISASM **op, FEProcessContext *process) {
    /*
     F7		0						TEST	r/m16/32	imm16/32					o..szapc	o..sz.pc	.....a..	o......c	Logical Compare
     F7		1		U12				TEST	r/m16/32	imm16/32					o..szapc	o..sz.pc	.....a..	o......c	Logical Compare
     F7		2						NOT	r/m16/32										One's Complement Negation
     F7		3						NEG	r/m16/32						o..szapc	o..szapc			Two's Complement Negation
     F7		4						MUL	eDX	eAX	r/m16/32				o..szapc	o......c	...szap.		Unsigned Multiply
     F7		5						IMUL	eDX	eAX	r/m16/32				o..szapc	o......c	...szap.		Signed Multiply
     F7		6						DIV	eDX	eAX	r/m16/32				o..szapc		o..szapc		Unsigned Divide
     F7		7						IDIV	eDX	eAX	r/m16/32				o..szapc		o..szapc		Signed Divide
     */
    
    if((*op)->Reserved_.REGOPCODE == 2) {
        uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
        uint32_t result = fe_threadContext_not(process->currentThread, arg1Value, (FEBitWidth)(*op)->Argument1.ArgSize);
        beu_store_value_in_arg(&(*op)->Argument1, result, process);
    } else if((*op)->Reserved_.REGOPCODE == 3) {
        uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
        uint32_t result = fe_threadContext_neg(process->currentThread, arg1Value, (FEBitWidth)(*op)->Argument1.ArgSize);
        beu_store_value_in_arg(&(*op)->Argument1, result, process);
    }
    else {
        assert((*op)->Argument1.ArgSize == (*op)->Argument2.ArgSize);
        uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
        uint32_t result;
        switch ((*op)->Reserved_.REGOPCODE) {
            case 0:
            case 1: {
                uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
                fe_threadContext_test(process->currentThread, arg1Value, arg2Value, (FEBitWidth)(*op)->Argument1.ArgSize);
            }
                return;
            case 4: {
                uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
                uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
                uint64_t result = fe_threadContext_mul32(process->currentThread, arg1Value, arg2Value, (FEBitWidth)(*op)->Argument1.ArgSize);
                if((*op)->Argument1.ArgSize == 16) {
                    fe_threadContext_setRegister16(process->currentThread, kAX, result&0xffff);
                    fe_threadContext_setRegister16(process->currentThread, kDX, (result>>16)&0xffff);
                } else if((*op)->Argument1.ArgSize == 32) {
                    process->currentThread->eax = result&0xffffffff;
                    process->currentThread->edx = (result>>32)&0xffffffff;
                } else {
                    assert(false);
                }
                return;
            }
                break;
            case 5: {
                //16 DX:AX ← AX ∗ r/m word.
                //32 EDX:EAX ← EAX ∗ r/m32.
                uint32_t arg1Value = beu_load_arg_value(&(*op)->Argument1, (uint32_t)(*op)->Instruction.Immediat, process);
                uint32_t arg2Value = beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
                uint64_t result = fe_threadContext_imul32(process->currentThread, arg1Value, arg2Value, (FEBitWidth)(*op)->Argument1.ArgSize);
                if((*op)->Argument1.ArgSize == 16) {
                    fe_threadContext_setRegister16(process->currentThread, kAX, result&0xffff);
                    fe_threadContext_setRegister16(process->currentThread, kDX, (result>>16)&0xffff);
                } else if((*op)->Argument1.ArgSize == 32) {
                    process->currentThread->eax = result&0xffffffff;
                    process->currentThread->edx = (result>>32)&0xffffffff;
                } else {
                    assert(false);
                }
                return;
            }
                break;
            case 6:
            case 7: {
                // 6 is div
                // 7 is idiv
                
                int64_t divident = 0;
                if((*op)->Argument2.ArgSize == 16) {
                    uint16_t dx = fe_threadContext_register16(process->currentThread, kDX);
                    uint16_t ax = fe_threadContext_register16(process->currentThread, kAX);
                    divident = beu_sign_extend((((uint32_t)dx<<16)&0xffff0000)|(ax&0xffff), k32bit);
                } else if((*op)->Argument2.ArgSize == 32) {
                    uint32_t edx = process->currentThread->edx;
                    uint32_t eax = process->currentThread->eax;
                    divident = (((uint64_t)edx<<32)&0xffffffff00000000) | (eax&0xffffffff);
                } else {
                    assert(false);
                }
                
                int64_t divider = 0;
                int64_t remainder = 0;
                int64_t quotient = 0;
                if((*op)->Reserved_.REGOPCODE == 7) {
                    //idiv, sign extend
                    divider = beu_sign_extend(beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process),(FEBitWidth)(*op)->Argument2.ArgSize);
                    quotient = fe_threadContext_idiv32(process->currentThread, divident, divider, (FEBitWidth)(*op)->Argument2.ArgSize, &remainder);

                } else if((*op)->Reserved_.REGOPCODE == 6) {
                    //div, no sign extend
                    divider = (uint64_t)beu_load_arg_value(&(*op)->Argument2, (uint32_t)(*op)->Instruction.Immediat, process);
                    quotient = fe_threadContext_div32(process->currentThread, divident, divider, (FEBitWidth)(*op)->Argument2.ArgSize, (uint64_t*)&remainder);
                }
                
                if((*op)->Argument2.ArgSize == 16) {
                /*
                 AX ← temp;
                 DX ← DX:AX SignedModulus SRC;
                 */
                    fe_threadContext_setRegister16(process->currentThread, kAX, quotient);
                    fe_threadContext_setRegister16(process->currentThread, kDX, remainder);

                } else if((*op)->Argument2.ArgSize == 32) {
                /*
                 EAX ← temp;
                 EDX ← EDXE:AX SignedModulus SRC;
                 */
                    process->currentThread->eax = (uint32_t)quotient;
                    process->currentThread->edx = (uint32_t)remainder;
                } else {
                    assert(false);
                }
                return;
            }
                break;
            default:
                assert(false);
                break;
        }
        beu_store_value_in_arg(&(*op)->Argument1, result, process);
    }
}

@end
