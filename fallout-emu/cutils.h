//
//  cutils.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 05/07/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#ifndef __fallout_emu__cutils__
#define __fallout_emu__cutils__

#include <stdio.h>
#include <inttypes.h>

#include "FECommonTypes.h"

char beu_carry_for_8(uint8_t v1, uint8_t v2);


int64_t beu_sign_extend_8(uint8_t value);
int64_t beu_sign_extend_16(uint16_t value);
int64_t beu_sign_extend(uint32_t value, FEBitWidth bitWidth);

#endif /* defined(__fallout_emu__cutils__) */
