//
//  FECPUFlags.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 28/04/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//
#ifndef __fallout_emu__FECPUFlags__
#define __fallout_emu__FECPUFlags__

#include <inttypes.h>

typedef struct FECPUFlags {
    uint16_t CF:1; // carry flag
    uint16_t PF:1; // parity flag
    uint16_t AF:1; // adjust flag
    uint16_t ZF:1; // zero flag
    uint16_t SF:1; // sign flag
    uint16_t TF:1; // trap flag
    uint16_t IF:1; // interrupt enable flag
    uint16_t DF:1; // direction flag
    uint16_t OF:1; // overflow flag
} FECPUFlags;


uint16_t fe_cpuflags_16(FECPUFlags cpuRegister);
void fe_cpuflags_fillParityFromByte(FECPUFlags *cpuRegister, uint8_t byte);
void fe_cpuflags_fillFrom16it(FECPUFlags *cpuRegister, uint16_t vector);


#endif
