//
//  FEmemoryMap.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#ifndef __fallout_emu__FEMemoryMap__
#define __fallout_emu__FEMemoryMap__

#include "FEMemoryAccessMode.h"
#include "FEMemoryMapBlock.h"
#include "FEArray.h"

typedef struct FEMemoryMap {
    uint32_t size;
    FEArray *memoryMapBlocksShadow;
    FEArray *memoryMapRightsShadow;
    FEArray *memoryMapBlocks;
    void(*memoryMapAccessModeChangeCallback)(struct FEMemoryMap*,FEMemoryAccessMode,uint32_t address, uint32_t size);
    
} FEMemoryMap;

FEMemoryMap *fe_memoryMap_create(uint32_t size);
void         fe_memoryMap_release(FEMemoryMap *memoryMap);

uint8_t  fe_memoryMap_map(FEMemoryMap *memoryMap, FEMemoryMapBlock *block, FEMemoryAccessMode accessMode);
uint32_t fe_memoryMap_malloc(FEMemoryMap *memoryMap, uint32_t size, FEMemoryAccessMode accessMode, const char *tag);
void     fe_memoryMap_free(FEMemoryMap *memoryMap, uint32_t address);

FEMemoryAccessMode fe_memoryMap_accessModeAtAddress(FEMemoryMap *memoryMap,uint32_t address);
void fe_memoryMap_setAccessModeAtAddress(FEMemoryMap *memoryMap, FEMemoryAccessMode mode, uint32_t address, uint32_t size);

uint32_t fe_memoryMap_value32AtAddress(FEMemoryMap *memoryMap, uint32_t address);
uint16_t fe_memoryMap_value16AtAddress(FEMemoryMap *memoryMap, uint32_t address);
uint8_t fe_memoryMap_value8AtAddress(FEMemoryMap *memoryMap, uint32_t address);

void fe_memoryMap_setValue32(FEMemoryMap *memoryMap, uint32_t address, uint32_t value);
void fe_memoryMap_setValue16(FEMemoryMap *memoryMap, uint32_t address, uint16_t value);
void fe_memoryMap_setValue8(FEMemoryMap *memoryMap, uint32_t address, uint8_t value);

void fe_memoryMap_memcpyToVirtualFromReal(FEMemoryMap *memoryMap, uint32_t dst, const void *src, uint32_t size);
void fe_memoryMap_memcpyToRealFromVirtual(FEMemoryMap *memoryMap, void *dst, uint32_t src, uint32_t size);
void fe_memoryMap_memcpyToVirtualFromVirtual(FEMemoryMap *memoryMap, uint32_t dst, uint32_t src, uint32_t size);

void fe_memoryMap_strncpyFromRealToVirtual(FEMemoryMap *memoryMap, uint32_t dst, const char *src, uint32_t size);
void fe_memoryMap_strcpyFromVirtualToAllocatedReal(FEMemoryMap *memoryMap, char **dst, uint32_t src);


FEMemoryMapBlock *fe_memoryMap_blockFromVirtualAddress(FEMemoryMap *memoryMap, uint32_t address);
FEMemoryMapBlock *fe_memoryMap_blockWithTag(FEMemoryMap *memoryMap, const char *const tag);

void fe_memoryMap_printDescription(const FEMemoryMap *memoryMap);


#endif