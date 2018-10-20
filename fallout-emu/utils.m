//
//  utils.c
//  fallout-emu
//
//  Created by Alexander Smirnov on 26/06/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "utils.h"

NSString *utils_memoryMap_createString(FEMemoryMap *memory, uint32_t address) {
    char *str;
    fe_memoryMap_strcpyFromVirtualToAllocatedReal(memory, &str, address);
    NSString * result = [[NSString alloc] initWithBytes: str length: strlen(str) encoding: NSASCIIStringEncoding];
    free(str);
    return result;
}