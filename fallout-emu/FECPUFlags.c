//
//  FECPUFlags.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 28/04/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include "FECPUFlags.h"

// FIXME:
// отключение оптимизации на этот метод решает проблемы с LTO.
// но нужно еще выяснить почем эти проблемы есть.
uint16_t fe_cpuflags_16(FECPUFlags cpuRegister) __attribute__((optnone))
{
    uint16_t result = 0;
    
    result = result | cpuRegister.CF;
    result = result | (cpuRegister.PF << 2);
    result = result | (cpuRegister.AF << 4);
    result = result | (cpuRegister.ZF << 6);
    result = result | (cpuRegister.SF << 7);
    //result = result | (1 << 9);
    result = result | (cpuRegister.DF << 10);
    result = result | (cpuRegister.OF << 11);
    
    return result;

}

void fe_cpuflags_fillParityFromByte(FECPUFlags *cpuRegister, uint8_t byte) {
    uint8_t setBits = (byte&1) + (1&(byte>>1)) + (1&(byte>>2)) + (1&(byte>>3)) + (1&(byte>>4)) + (1&(byte>>5)) + (1&(byte>>6)) + (1&(byte>>7));
    cpuRegister->PF = setBits%2 == 0;
}

void fe_cpuflags_fillFrom16it(FECPUFlags *cpuRegister, uint16_t vector)// __attribute__((optnone))
{
    cpuRegister->CF = vector & 1;
    cpuRegister->PF = (vector>>2)&1;
    cpuRegister->AF = (vector>>4)&1;
    cpuRegister->ZF = (vector>>6)&1;
    cpuRegister->SF = (vector>>7)&1;
    cpuRegister->DF = (vector>>10)&1;
    cpuRegister->OF = (vector>>11)&1;
}
