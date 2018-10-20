//
//  beaengine_utils.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 25/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include "beaengine/BeaEngine.h"
#include <inttypes.h>

#include "FEThreadContext.h"
#import "FECommonTypes.h"
#import "FEFPU.h"
#include "FEArray.h"

typedef struct FEProcessContext FEProcessContext;
typedef struct DisasmContext {
    int32_t *indexes;
    FEArray *disasmed;
    FEArray *lens;
} DisasmContext;

void beu_update_disasm_from_context(DISASM **disasm_op, int *len, uint8_t *modrm, FEProcessContext *process);

uint32_t beu_load_arg_value(ARGTYPE * arg, uint32_t immediat, FEProcessContext *process);
void beu_store_value_in_arg(ARGTYPE * arg, uint32_t value, FEProcessContext *process);

FERegisterName beu_register32_from_argtype(Int32 argtype, Int32 argposition);

FERegisterName beu_register16_from_argtype(Int32 argtype, Int32 argposition);

FERegisterName beu_register8_from_argtype(Int32 argtype, Int32 argposition);

FERegisterName beu_register_from_argtype(Int32 argtype, Int32 argposition, FEBitWidth bitWidth);

FERegisterName beu_seg_register_from_argtype(Int32 argtype);

FEFPURegisterName beu_fpu_register_from_argtype(Int32 argtype);

uint32_t beu_address_from_argtype(ARGTYPE * address_arg, FEProcessContext *process);

uint8_t  beu_load_8bit(ARGTYPE * address_arg, FEProcessContext *process);
uint16_t beu_load_16bit(ARGTYPE * address_arg, FEProcessContext *process);
uint32_t beu_load_32bit(ARGTYPE * address_arg, FEProcessContext *process);

uint32_t beu_load(ARGTYPE * address_arg, FEProcessContext *process, FEBitWidth bitWidth);

void beu_store_8bit(uint8_t value, ARGTYPE *address_arg, FEProcessContext *process);
void beu_store_16bit(uint16_t value, ARGTYPE *address_arg, FEProcessContext *process);
void beu_store_32bit(uint32_t value, ARGTYPE *address_arg, FEProcessContext *process);

void beu_store(uint32_t value, ARGTYPE *address_arg, FEProcessContext *process, FEBitWidth bitWidth);