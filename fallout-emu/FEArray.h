//
//  FEArray.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 02/06/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#ifndef __fallout_emu__FEArray__
#define __fallout_emu__FEArray__

#include <stdio.h>
#include <inttypes.h>

extern uint32_t FENotFound;

typedef enum FEComparisonResult {
    FEComparisonResult_Ascendent,
    FEComparisonResult_Descendent,
    FEComparisonResult_Same
} FEComparisonResult;

typedef struct FEArray {
    void *p;
    void(*cleanup)(void*);
    uint32_t size;
    uint32_t capacity;
    uint32_t element_size;
    uint8_t allocate_zeroed;
} FEArray;

FEArray *fe_array_create(uint32_t element_size, uint32_t capacity, uint8_t allocate_zeroed);
void fe_array_release(FEArray *array);

#define fe_array_index_addr(ARRAY,INDEX) ((void*)(((char*)(ARRAY->p))+(ARRAY->element_size*(INDEX))))
#define fe_array_index(ARRAY,TYPE,INDEX) (((TYPE*)(ARRAY->p))[INDEX])
#define fe_array_last(ARRAY,TYPE) fe_array_index(ARRAY,TYPE,(ARRAY->size-1))

int8_t fe_array_append(FEArray *array,const void *element);
int8_t fe_array_insert(FEArray *array, uint32_t index, const void *element);
int8_t fe_array_remove_index(FEArray *array, uint32_t index);
void   fe_array_swap(FEArray *array, uint32_t index1, uint32_t index2);

uint32_t fe_array_index_of(FEArray *array, const void *element);

void fe_array_merge_sort(FEArray *array,FEComparisonResult(*compare)(const void*, const void*));

#endif /* defined(__fallout_emu__FEArray__) */
