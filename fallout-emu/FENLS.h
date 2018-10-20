//
//  FENLS.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 28/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#include <inttypes.h>

#define CP_ACP        0
#define CP_OEMCP      1
#define CP_MACCP      2
#define CP_THREAD_ACP 3
#define CP_SYMBOL     42
#define CP_UTF7       65000
#define CP_UTF8       65001

typedef struct
{
    uint32_t MaxCharSize;
    char DefaultChar[2];
    char LeadByte[12];
} CPINFO, *LPCPINFO;