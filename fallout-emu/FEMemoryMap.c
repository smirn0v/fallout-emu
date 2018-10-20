//
//  FEmemoryMap.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 22/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include "FEMemoryMap.h"
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)<(b))?(b):(a))

#define ALIGNMENT 4096
#define SHADOW_BLOCK_SIZE ALIGNMENT

uint8_t    _fe_memory_map_appendMemoryBlock(FEMemoryMap *memoryMap, FEMemoryMapBlock *block, FEMemoryAccessMode mode);
uint8_t    _fe_memory_map_isMemoryMapBlockAvailable(FEMemoryMap *memoryMap, uint32_t address, uint32_t size);
char      *_fe_memory_map_localAddressFromVirtualAddress(const FEMemoryMap *memoryMap, uint32_t virtualAddress, uint32_t size, FEMemoryAccessMode access);

FEMemoryMap *fe_memoryMap_create(uint32_t size) {
    FEMemoryMap *map = (FEMemoryMap*)malloc(sizeof(FEMemoryMap));
    
    if(!map) {
        return 0;
    }
    map->memoryMapAccessModeChangeCallback = NULL;
    map->size = size;
    
    map->memoryMapBlocksShadow = fe_array_create(sizeof(FEMemoryMapBlock*), size/SHADOW_BLOCK_SIZE+1,0);
    
    if(!map->memoryMapBlocksShadow) {
        free(map);
        return 0;
    }
    
    memset(map->memoryMapBlocksShadow->p, 0, map->memoryMapBlocksShadow->element_size * map->memoryMapBlocksShadow->capacity);
    map->memoryMapBlocksShadow->size = map->memoryMapBlocksShadow->capacity;
    
    map->memoryMapRightsShadow = fe_array_create(sizeof(FEMemoryAccessMode), size/SHADOW_BLOCK_SIZE+1,0);
    
    if(!map->memoryMapRightsShadow) {
        fe_array_release(map->memoryMapBlocksShadow);
        free(map);
        return 0;
    }
    
    memset(map->memoryMapRightsShadow->p, 0, map->memoryMapRightsShadow->element_size * map->memoryMapRightsShadow->capacity);
    map->memoryMapRightsShadow->size = map->memoryMapRightsShadow->capacity;
    
    map->memoryMapBlocks = fe_array_create(sizeof(FEMemoryMapBlock*), 16, 0);
    
    if(!map->memoryMapBlocks) {
        fe_array_release(map->memoryMapRightsShadow);
        fe_array_release(map->memoryMapBlocksShadow);
        free(map);
        return 0;
    }
    
    return map;
}

void         fe_memoryMap_release(FEMemoryMap *memoryMap) {
    
    if(!memoryMap) {
        return;
    }
    
    fe_array_release(memoryMap->memoryMapRightsShadow);
    fe_array_release(memoryMap->memoryMapBlocksShadow);
    fe_array_release(memoryMap->memoryMapBlocks);
    free(memoryMap);
}

uint8_t  fe_memoryMap_map(FEMemoryMap *memoryMap, FEMemoryMapBlock *block, FEMemoryAccessMode accessMode) {
    return _fe_memory_map_appendMemoryBlock(memoryMap, block, accessMode);
}

uint32_t fe_memoryMap_malloc(FEMemoryMap *memoryMap, uint32_t size, FEMemoryAccessMode accessMode, const char *tag) {
    
    // malloc will never allocate at 0
    uint32_t start_address = ALIGNMENT;
    char *realAddress = malloc(size);
    
    if(!realAddress) {
        assert(0);
        return 0;
    }
    
    FEMemoryMapBlock *newBlock = fe_memoryMapBlock_create(tag);
    
    if(!newBlock) {
        goto early_fail;
    }
    
    newBlock->localAddress     = realAddress;
    newBlock->size             = size;
    newBlock->freeWhenDone     = 1;

    for(uint32_t i = 0; i < memoryMap->memoryMapBlocks->size; i++) {
        FEMemoryMapBlock *first = fe_array_index(memoryMap->memoryMapBlocks, FEMemoryMapBlock*, i);
        if(i == 0) {
            if((first->virtualAddress>start_address) && (size < first->virtualAddress-start_address)) {
                newBlock->virtualAddress   = start_address;
                newBlock->end = newBlock->virtualAddress + newBlock->size;
                _fe_memory_map_appendMemoryBlock(memoryMap, newBlock, accessMode);

                return start_address;
            }
        }
        if(i + 1 < memoryMap->memoryMapBlocks->size) {
            FEMemoryMapBlock *second  = fe_array_index(memoryMap->memoryMapBlocks, FEMemoryMapBlock*, i+1);
            uint32_t address = first->virtualAddress + first->size;
            address = (address/ALIGNMENT+1*(address%ALIGNMENT != 0))*ALIGNMENT;
            
            if(address + size < second->virtualAddress) {
                newBlock->virtualAddress = address;
                newBlock->end = newBlock->virtualAddress + newBlock->size;
                _fe_memory_map_appendMemoryBlock(memoryMap, newBlock, accessMode);

                return address;
            }
        }
    }
    
    if(memoryMap->memoryMapBlocks->size == 0) {
        if(size > memoryMap->size - start_address) {
            goto fail;
        }
        
        newBlock->virtualAddress = start_address;
        newBlock->end = newBlock->virtualAddress + newBlock->size;

        _fe_memory_map_appendMemoryBlock(memoryMap, newBlock, accessMode);
        return start_address;
    }
    
    FEMemoryMapBlock *lastBlock = fe_array_last(memoryMap->memoryMapBlocks, FEMemoryMapBlock*);
    uint32_t address = lastBlock->virtualAddress + lastBlock->size;
    address = (address/ALIGNMENT+1*(address%ALIGNMENT != 0))*ALIGNMENT;
    if(address + size >= memoryMap->size) {
        goto fail;
    }
    
    newBlock->virtualAddress = address;

    newBlock->end = newBlock->virtualAddress + newBlock->size;
    _fe_memory_map_appendMemoryBlock(memoryMap, newBlock, accessMode);
    return address;
    
fail:
    fe_memoryMapBlock_release(newBlock);
early_fail:
    free(realAddress);
    assert(0);
    return 0;
}


void     fe_memoryMap_free(FEMemoryMap *memoryMap, uint32_t address) {
    //FEMemoryMapBlock *block = fe_array_index(memoryMap->memoryMapBlocksShadow, FEMemoryMapBlock*, address/SHADOW_BLOCK_SIZE);
    //TODO: free block
    void *shadow = fe_array_index_addr(memoryMap->memoryMapBlocksShadow, address/SHADOW_BLOCK_SIZE);
    memset(shadow,0,memoryMap->memoryMapBlocksShadow->element_size);
}

FEMemoryAccessMode fe_memoryMap_accessModeAtAddress(FEMemoryMap *memoryMap,uint32_t address) {
    return fe_array_index(memoryMap->memoryMapRightsShadow, FEMemoryAccessMode, address/SHADOW_BLOCK_SIZE);
}

void fe_memoryMap_setAccessModeAtAddress(FEMemoryMap *memoryMap, FEMemoryAccessMode mode, uint32_t address, uint32_t size) {
    uint32_t sindex = address/SHADOW_BLOCK_SIZE;
    uint32_t eindex = (address+size-1)/SHADOW_BLOCK_SIZE;
    for(;sindex<eindex;sindex++) {
        fe_array_index(memoryMap->memoryMapRightsShadow, FEMemoryAccessMode, sindex) = mode;
    }
    if(memoryMap->memoryMapAccessModeChangeCallback) {
        memoryMap->memoryMapAccessModeChangeCallback(memoryMap, mode, address, size);
    }
}

uint32_t fe_memoryMap_value32AtAddress(FEMemoryMap *memoryMap, uint32_t address) {
    void *ptr = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, address, 4, kFEMemoryAccessMode_Read);

    //if(ptr) {
        return *((uint32_t*)ptr);
    // }
    
    // return 0;
}

uint16_t fe_memoryMap_value16AtAddress(FEMemoryMap *memoryMap, uint32_t address) {
    void *ptr = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, address, 2, kFEMemoryAccessMode_Read);
    
    // if(ptr) {
        return *((uint16_t*)ptr);
    // }
    
    // return 0;
}

uint8_t fe_memoryMap_value8AtAddress(FEMemoryMap *memoryMap, uint32_t address) {
    void *ptr = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, address, 1, kFEMemoryAccessMode_Read);
    
    // if(ptr) {
        return *((uint8_t*)ptr);
    // }
    
    // return 0;
}

void fe_memoryMap_setValue32(FEMemoryMap *memoryMap, uint32_t address, uint32_t value) {
    void *ptr = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, address, 4, kFEMemoryAccessMode_Write);
    //if(ptr) {
        *((uint32_t*)ptr) = value;
    //}
}

void fe_memoryMap_setValue16(FEMemoryMap *memoryMap, uint32_t address, uint16_t value) {
    void *ptr = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, address, 2, kFEMemoryAccessMode_Write);
    // if(ptr) {
        *((uint16_t*)ptr) = value;
    //}
}

void fe_memoryMap_setValue8(FEMemoryMap *memoryMap, uint32_t address, uint8_t value) {
    void *ptr = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, address, 1, kFEMemoryAccessMode_Write);
    //if(ptr) {
        *((uint8_t*)ptr) = value;
    //}
}

void fe_memoryMap_memcpyToVirtualFromReal(FEMemoryMap *memoryMap, uint32_t dst, const void *src, uint32_t size) {
    void *dstp = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, dst, size, kFEMemoryAccessMode_Write);
    memcpy(dstp, src, size);
}

void fe_memoryMap_memcpyToRealFromVirtual(FEMemoryMap *memoryMap, void *dst, uint32_t src, uint32_t size) {
    void *srcp = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, src, size, kFEMemoryAccessMode_Read);
    memcpy(dst, srcp, size);
}

void fe_memoryMap_memcpyToVirtualFromVirtual(FEMemoryMap *memoryMap, uint32_t dst, uint32_t src, uint32_t size) {
    void *srcp = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, src, size, kFEMemoryAccessMode_Read);
    void *dstp = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, dst, size, kFEMemoryAccessMode_Write);
    memcpy(dstp, srcp, size);
}

void fe_memoryMap_strncpyFromRealToVirtual(FEMemoryMap *memoryMap, uint32_t dst, const char *src, uint32_t size) {
    uint32_t rsize = (uint32_t)MIN(size-1,strlen(src));
    fe_memoryMap_memcpyToVirtualFromReal(memoryMap, dst, src, rsize);
    fe_memoryMap_setValue8(memoryMap, dst+rsize, 0);
}

void fe_memoryMap_strcpyFromVirtualToAllocatedReal(FEMemoryMap *memoryMap, char **dst, uint32_t src) {
    assert(dst);
    if(!dst) {
        return;
    }
    
    char *srcp = _fe_memory_map_localAddressFromVirtualAddress(memoryMap, src, 1, kFEMemoryAccessMode_Read);
    size_t len = strlen(srcp);
    assert(len<4095);
    
    char *result = malloc(len+1);
    assert(result);
    memset(result,0,len+1);
    
    strncpy(result, srcp, len);
    *dst = result;
}


//inline FEMemoryMapBlock *fe_memoryMap_blockFromVirtualAddress(FEMemoryMap *memoryMap, uint32_t address) {
//    return fe_array_index(memoryMap->memoryMapBlocksShadow, FEMemoryMapBlock*, address/SHADOW_BLOCK_SIZE);
//}

FEMemoryMapBlock *fe_memoryMap_blockWithTag(FEMemoryMap *memoryMap, const char *const tag) {
    for(uint32_t i = 0; i < memoryMap->memoryMapBlocks->size; i++) {
        FEMemoryMapBlock *block = fe_array_index(memoryMap->memoryMapBlocks, FEMemoryMapBlock*, i);
        assert(block);
        if(strcmp(block->tag, tag) == 0) {
            return block;
        }
    }
    return 0;
}

uint8_t _fe_memory_map_appendMemoryBlock(FEMemoryMap *memoryMap, FEMemoryMapBlock *block, FEMemoryAccessMode mode) {
    assert(memoryMap && block);

//    if(!_fe_memory_map_isMemoryMapBlockAvailable(memoryMap, block->virtualAddress, block->size)) {
//        assert(-1);
//        return 0;
//    }

    for(uint32_t shadowIndex = block->virtualAddress/SHADOW_BLOCK_SIZE;
        shadowIndex <= (block->size+block->virtualAddress-1)/SHADOW_BLOCK_SIZE;
        shadowIndex++) {
        
        FEMemoryMapBlock *currentBlock = fe_array_index(memoryMap->memoryMapBlocksShadow, FEMemoryMapBlock*, shadowIndex);
#pragma unused(currentBlock)
        assert(currentBlock==0);

        fe_array_index(memoryMap->memoryMapBlocksShadow, FEMemoryMapBlock*, shadowIndex) = block;
    }

    fe_array_append(memoryMap->memoryMapBlocks, &block);
    fe_array_merge_sort(memoryMap->memoryMapBlocks, &fe_memoryMapBlock_compare);
    
    fe_memoryMap_setAccessModeAtAddress(memoryMap, mode, block->virtualAddress, block->size);
    
    return 1;
}

uint8_t _fe_memory_map_isMemoryMapBlockAvailable(FEMemoryMap *memoryMap, uint32_t address, uint32_t size) {
    
    // 0 1 2 3 4 5 6 7 | 8 9 10 11 12 13 14 15 | 16 17 18
    //        0                    1                 2
    //FIXME ???
    for(uint32_t shadowAddress = address; shadowAddress < address+size; shadowAddress+=SHADOW_BLOCK_SIZE) {
        uint32_t index = shadowAddress/SHADOW_BLOCK_SIZE;
        FEMemoryMapBlock *block = fe_array_index(memoryMap->memoryMapBlocksShadow, FEMemoryMapBlock*, index);
        if(block) {
            return 0;
        }
    }
    
    return 1;
}

char *_fe_memory_map_localAddressFromVirtualAddress(const FEMemoryMap *memoryMap, uint32_t virtualAddress, uint32_t size, FEMemoryAccessMode access) {
    FEMemoryMapBlock* block = fe_array_index(memoryMap->memoryMapBlocksShadow, FEMemoryMapBlock*, virtualAddress/SHADOW_BLOCK_SIZE);
//    assert(block);
//    
//    if(!block) {
//        return 0;
//    }
//    
//    if((block->accessMode & access) != access) {
//        printf("Error access to block vaddress = 0x%X, access = 0x%X. Accessed as 0x%X\n", block->virtualAddress, block->accessMode, access);
//        assert(0);
//    }
//    if(access & kFEMemoryAccessMode_Write) {
//        if(block->context) {
//            typedef struct DisasmContext {
//                int32_t *indexes;
//                FEArray *disasmed;
//                FEArray *lens;
//            } DisasmContext;
//            DisasmContext *context = block->context;
//            free(context->disasmed);
//            free(context->lens);
//            free(context->indexes);
//            free(context);
//            block->context = NULL;
//        }
//    }
    
    return block->localAddress+(virtualAddress - block->virtualAddress);
}

void fe_memoryMap_printDescription(const FEMemoryMap *memoryMap) {
    for(uint32_t i = 0; i< memoryMap->memoryMapBlocks->size; i++) {
        FEMemoryMapBlock *block = fe_array_index(memoryMap->memoryMapBlocks, FEMemoryMapBlock*, i);
        printf("{%s vaddr: 0x%X size: %d}\n", block->tag, block->virtualAddress, block->size);
    }
}
