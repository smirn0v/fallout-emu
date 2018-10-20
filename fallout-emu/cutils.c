//
//  cutils.c
//  fallout-emu
//
//  Created by Alexander Smirnov on 05/07/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include <assert.h>

#include "cutils.h"


char beu_carry_for_8(uint8_t v1, uint8_t v2) {
    uint16_t v16_1 = v1;
    uint16_t v16_2 = v2;
    
    return (v1+v2) != (v16_1+v16_2);
}

int64_t beu_sign_extend_8(uint8_t value) {
    int8_t originalValue = value;
    return (int64_t)originalValue;
}

int64_t beu_sign_extend_16(uint16_t value) {
    int16_t originalValue = value;
    return (int64_t)originalValue;
}

int64_t beu_sign_extend(uint32_t value, FEBitWidth bitWidth) {
    switch(bitWidth) {
        case k32bit: {
            return (int32_t)value;
        }
        case k16bit: {
            return beu_sign_extend_16(value);
        }
        case k8bit: {
            return beu_sign_extend_8(value);
        }
        default:
            assert(0);
    }
}
