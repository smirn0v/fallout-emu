//
//  FETime.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 12/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include <inttypes.h>

#define TICKSPERSEC        10000000
#define SECSPERDAY         86400
/* 1601 to 1970 is 369 years plus 89 leap days */
#define SECS_1601_TO_1970  ((369 * 365 + 89) * (uint64_t)SECSPERDAY)
#define TICKS_1601_TO_1970 (SECS_1601_TO_1970 * TICKSPERSEC)

typedef struct _FILETIME
{
    uint32_t dwLowDateTime;
    uint32_t dwHighDateTime;
} FILETIME, *PFILETIME, *LPFILETIME;