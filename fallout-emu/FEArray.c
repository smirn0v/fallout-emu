//
//  FEArray.c
//  fallout-emu
//
//  Created by Alexander Smirnov on 02/06/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include "FEArray.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>

uint32_t FENotFound = UINT32_MAX;

void *_fe_array_alloc(FEArray *array, size_t size);
void _merge(FEArray *arr, int l, int m, int r, FEComparisonResult(*compare)(const void*, const void*));
void _mergeSort(FEArray *arr, int l, int r, FEComparisonResult(*compare)(const void*, const void*));

FEArray *fe_array_create(uint32_t element_size, uint32_t capacity, uint8_t allocate_zeroed) {
    FEArray *array = malloc(sizeof(FEArray));
    
    if(!array) {
        return 0;
    }
    array->allocate_zeroed = allocate_zeroed;

    array->p = _fe_array_alloc(array, element_size * capacity);
    
    if(!array->p) {
        free(array);
        return 0;
    }
    
    array->cleanup = 0;
    array->element_size = element_size;
    array->size = 0;
    array->capacity = capacity;
    
    return array;
}

void fe_array_release(FEArray *array) {
    if(!array) {
        return;
    }
    
    if(array->cleanup) {
        char *p = array->p;
        for(uint32_t i = 0; i < array->size; i++) {
            array->cleanup(p);
            p+=array->element_size;
        }
    }
    free(array->p);
    free(array);
}

int8_t fe_array_append(FEArray *array,const void *element) {
    if(!array) {
        return 0;
    }
    
    if(array->size >= array->capacity) {
        uint32_t capacity = array->capacity*3/2+1;
        // realloc may lose part of initial array
        // on fail. so using malloc here
        void *p = _fe_array_alloc(array, capacity*array->element_size);
        
        if(!p) {
            return 0;
        }
        memcpy(p, array->p, array->size*array->element_size);
        free(array->p);
        array->p = p;
        array->capacity = capacity;
    }
    
    uint32_t index = array->size;
    void *el = (char*)array->p + index*array->element_size;
    memcpy(el,element,array->element_size);
    array->size = index+1;
    
    return 1;
}

int8_t fe_array_insert(FEArray *array, uint32_t index, const void *element) {
    assert(array);
    assert(index < array->size);
    if(!array || index >= array->size) {
        return 0;
    }
    
    if(array->capacity - array->size < 1) {
        void *dummy = _fe_array_alloc(array, array->element_size);
        assert(dummy);
        if(!dummy) {
            return 0;
        }
        fe_array_append(array, dummy);
        free(dummy);
    }
    
    void *src = ((char*)array->p)+array->element_size*index;
    void *dst = ((char*)array->p)+array->element_size*(index+1);

    void *temp = malloc(array->element_size*array->size-index);
    assert(temp);
    if(!temp) {
        return 0;
    }
    memcpy(temp, src, array->element_size*array->size-index);
    memcpy(dst, temp, array->element_size*array->size-index);
    memcpy(src, element, array->element_size);
    
    free(temp);
    
    return 1;
}

int8_t fe_array_remove_index(FEArray *array, uint32_t index) {
    assert(array);
    assert(index < array->size);
    
    if(index >= array->size) {
        return 0;
    }
    
    if(array->cleanup) {
        array->cleanup(fe_array_index_addr(array, index));
    }

    if((array->size-1) > index) {
        uint32_t size = array->element_size*(array->size-1-index);
        void *temp = malloc(size);
        assert(temp);
        if(!temp) {
            return 0;
        }
        memcpy(temp, fe_array_index_addr(array, index+1), size);
        memcpy(fe_array_index_addr(array, index), temp, size);
        free(temp);
    }
    array->size--;
    return 1;
}

inline void fe_array_swap(FEArray *array, uint32_t index1, uint32_t index2) {
    uint8_t tmp_on_stack[array->element_size];
    void *tmp = &tmp_on_stack;
    
    memcpy(tmp, fe_array_index_addr(array, index1), array->element_size);
    memcpy(fe_array_index_addr(array, index1), fe_array_index_addr(array, index2), array->element_size);
    memcpy(fe_array_index_addr(array, index2), tmp, array->element_size);
}

uint32_t fe_array_index_of(FEArray *array, const void *element) {
    for(uint32_t i = 0; i<array->size; i++) {
        void *ref = fe_array_index_addr(array, i);
        if(memcmp(ref, element, array->element_size) == 0) {
            return i;
        }
    }
    return FENotFound;
}


void fe_array_merge_sort(FEArray *array,FEComparisonResult(*compare)(const void*, const void*)) {
    _mergeSort(array, 0, array->size-1, compare);
}

void *_fe_array_alloc(FEArray *array, size_t size) {
    if(array->allocate_zeroed) {
        return calloc(size, 1);
    }
    return malloc(size);
}

/* Function to merge the two haves arr[l..m] and arr[m+1..r] of array arr[] */
void _merge(FEArray *arr, int l, int m, int r, FEComparisonResult(*compare)(const void*, const void*))
{
    int i, j, k;
    int n1 = m - l + 1;
    int n2 =  r - m;
    
    /* create temp arrays */
    
    FEArray *L = fe_array_create(arr->element_size, n1,0);
    FEArray *R = fe_array_create(arr->element_size, n2,0);
    assert(L && R);
    
    /* Copy data to temp arrays L[] and R[] */
    for(i = 0; i < n1; i++) {
        void *src = fe_array_index_addr(arr, l+i);
        void *dst = fe_array_index_addr(L,i);
        memcpy(dst,src,arr->element_size);
    }
    for(j = 0; j < n2; j++) {
        void *src = fe_array_index_addr(arr, m+1+j);
        void *dst = fe_array_index_addr(R,j);
        memcpy(dst,src,arr->element_size);
    }
    
    /* Merge the temp arrays back into arr[l..r]*/
    i = 0;
    j = 0;
    k = l;
    while (i < n1 && j < n2)
    {
        void *left = fe_array_index_addr(L, i);
        void *right = fe_array_index_addr(R, j);
        FEComparisonResult comparison = compare(left,right);
        if (comparison == FEComparisonResult_Ascendent || comparison == FEComparisonResult_Same)
        {
            void *dst = fe_array_index_addr(arr, k);
            void *src = fe_array_index_addr(L, i);
            memcpy(dst,src,arr->element_size);

            i++;
        }
        else
        {
            void *dst = fe_array_index_addr(arr, k);
            void *src = fe_array_index_addr(R, j);
            memcpy(dst,src,arr->element_size);
            j++;
        }
        k++;
    }
    
    /* Copy the remaining elements of L[], if there are any */
    while (i < n1)
    {
        void *dst = fe_array_index_addr(arr, k);
        void *src = fe_array_index_addr(L, i);
        memcpy(dst,src,arr->element_size);

        i++;
        k++;
    }
    
    /* Copy the remaining elements of R[], if there are any */
    while (j < n2)
    {
        void *dst = fe_array_index_addr(arr, k);
        void *src = fe_array_index_addr(R, j);
        memcpy(dst,src,arr->element_size);

        j++;
        k++;
    }
    
    fe_array_release(L);
    fe_array_release(R);
}

/* l is for left index and r is right index of the sub-array
 of arr to be sorted */
void _mergeSort(FEArray *arr, int l, int r, FEComparisonResult(*compare)(const void*, const void*))
{
    if (l < r)
    {
        int m = l+(r-l)/2; //Same as (l+r)/2, but avoids overflow for large l and h
        _mergeSort(arr, l, m, compare);
        _mergeSort(arr, m+1, r, compare);
        _merge(arr, l, m, r, compare);
    }
}