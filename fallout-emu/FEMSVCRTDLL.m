//
//  FEMSVCRTDLL.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 15/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEMSVCRTDLL.h"
#include "FEThreadContext.h"
#include "FEMemoryMap.h"
#import "FEProcess.h"
#import "NSString+FE.h"


// CDECL calling convention
// caller cleans up the stack

/*
 unsigned int _controlfp(
 unsigned int new,
 unsigned int mask
 );
 */
static uint8_t fe__controlfp(FEProcess *process) {
    process.currentThread->eax = 0;;
    return 0;
}

/*
 void __set_app_type (
 int at
 )
 */
static uint8_t fe___set_app_type(FEProcess *process) {
    return 0;
}

/*
 int __getmainargs(
 int * _Argc,
 char *** _Argv,
 char *** _Env,
 int _DoWildCard,
 int *mode);
 */
static uint8_t fe___getmainargs(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t _argc = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t _argv = fe_memoryMap_value32AtAddress(process.memory,  ptrToArgs+4);
    uint32_t _env  = fe_memoryMap_value32AtAddress(process.memory,  ptrToArgs+8);
    // uint32_t _doWildCard = fe_memoryMap_value32AtAddress(process.memory,  ptrToArgs+12);
    //uint32_t _mode = fe_memoryMap_value32AtAddress(process.memory,  ptrToArgs+16);
    
    assert(_argc != 0);
    assert(_argv != 0);
    assert(_env != 0);
    
    fe_memoryMap_setValue32(process.memory, _argc, 1);

    uint32_t argvArray = fe_memoryMap_malloc(process.memory, 8, kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[ @".argv array from __getmainargs" cStringUsingEncoding: NSASCIIStringEncoding]);
    
    uint32_t path = fe_memoryMap_malloc(process.memory, (uint32_t)process.path.length+1, kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[ @".path from __getmainargs" cStringUsingEncoding: NSASCIIStringEncoding]);
    
    fe_memoryMap_strncpyFromRealToVirtual(process.memory,
                                          path,
                                          (char*)[process.path cStringUsingEncoding: NSASCIIStringEncoding],
                                          (uint32_t)process.path.length+1);
 
    fe_memoryMap_setValue32(process.memory,argvArray,path);
    fe_memoryMap_setValue32(process.memory,argvArray+4,0);
    
    fe_memoryMap_setValue32(process.memory,_argv,argvArray);
    fe_memoryMap_setValue32(process.memory,_env,0);
    
    process.currentThread->eax = 0;;
    
    return 0;
}

static uint8_t fe_printf(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t arg_format = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    char *formatC ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&formatC , arg_format);
    
    NSString* formatStr = [NSString stringWithCString: formatC encoding: NSASCIIStringEncoding];

    char buffer[256];
    
    // args not supported
    uint8_t inputs =  [formatStr fe_countOccurencesOfString: @"%"];
    if(inputs == 0) {
        snprintf(buffer, sizeof(buffer), "%s", formatC);
    } else if(inputs == 1) {
        if([formatStr containsString:@"%s"] || [formatStr containsString:@"%-10s"]) {
            uint32_t input1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
            char *input1Cstr ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&input1Cstr , input1);
            snprintf(buffer, sizeof(buffer), formatC, input1Cstr);
            free(input1Cstr);
        } else if([formatStr containsString:@"%04lx"] ||[formatStr containsString:@"%04x"] ||[formatStr containsString:@"%08lx"] ||[formatStr containsString:@"%x"] || [formatStr containsString:@"%02x"] || [formatStr containsString:@"%d"]) {
            uint32_t input1 = (uint32_t)fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
            snprintf(buffer, sizeof(buffer), formatC, input1);
        } else if([formatStr containsString: @"%f\n"]) {
            double_t input1;
            fe_memoryMap_memcpyToRealFromVirtual(process.memory, &input1, ptrToArgs+4, sizeof(input1));
            snprintf(buffer, sizeof(buffer), "%f\n", input1);
        } else {
            assert(false);
        }
        
    } else if(inputs == 5 && [formatStr isEqualToString: @"%-10s A=%08lx B=%08lx R=%08lx CC=%04lx\n"]) {
        uint32_t str = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
        uint32_t hexV1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
        uint32_t hexV2 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
        uint32_t hexV3 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
        uint32_t hexV4 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+20);
        
        char *strC ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&strC , str);
        snprintf(buffer, sizeof(buffer),"%-10s A=%08x B=%08x R=%08x CC=%04x\n", strC, hexV1, hexV2, hexV3, hexV4);
        free(strC);
    } else if(inputs == 7 && [formatStr isEqualToString:@"%-10s AH=%08lx AL=%08lx B=%08lx RH=%08lx RL=%08lx CC=%04lx\n"]) {
        uint32_t str = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
        uint32_t hexV1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
        uint32_t hexV2 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
        uint32_t hexV3 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
        uint32_t hexV4 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+20);
        uint32_t hexV5 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+24);
        uint32_t hexV6 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+28);
        
        char *strC ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&strC , str);
        snprintf(buffer, sizeof(buffer),"%-10s AH=%08x AL=%08x B=%08x RH=%08x RL=%08x CC=%04x\n", strC, hexV1, hexV2, hexV3, hexV4, hexV5, hexV6);
        free(strC);
    } else if(inputs == 5 && [formatStr isEqualToString:@"%-10s A=%08x R=%08x CCIN=%04x CC=%04x\n"]) {
        uint32_t str = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
        uint32_t hexV1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
        uint32_t hexV2 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
        uint32_t hexV3 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
        uint32_t hexV4 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+20);
        
        char *strC ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&strC , str);
        snprintf(buffer, sizeof(buffer),"%-10s A=%08x R=%08x CCIN=%04x CC=%04x\n", strC, hexV1, hexV2, hexV3, hexV4);
        free(strC);
    } else if (inputs == 2 && [formatStr isEqualToString:@"%-10s %d\n"]) {
        uint32_t str = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
        int32_t v1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
        char *strC ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&strC , str);
        snprintf(buffer, sizeof(buffer),"%-10s %d\n", strC, v1);
        free(strC);
    } else if (inputs == 2 && [formatStr isEqualToString:@"%-10s R=%08lx\n"]) {
        uint32_t str = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
        unsigned long v1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
        char *strC ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&strC , str);
        snprintf(buffer, sizeof(buffer),"%-10s R=%08lx\n", strC, v1);
        free(strC);
    } else {
        assert(false);
    }
    
    free(formatC);
    
    [process addToStdout: [NSString stringWithCString: buffer encoding: NSASCIIStringEncoding]];
    
    return 0;
}

static uint8_t fe_exit(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t exitCode = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    [process exit: exitCode];
    
    return 0;
}

static uint8_t fe_strlen(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t arg_strAddr = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    

    char *str ; fe_memoryMap_strcpyFromVirtualToAllocatedReal(process.memory,&str , arg_strAddr);
    
    process.currentThread->eax = (uint32_t)strlen(str);
    
    free(str);
    
    return 0;
}

// void * memcpy(void *restrict dst, const void *restrict src, size_t n);
static uint8_t fe_memcpy(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t arg_dst = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_src = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_n = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
    fe_memoryMap_memcpyToVirtualFromVirtual(process.memory,  arg_dst,  arg_src,  arg_n);

    process.currentThread->eax = arg_dst;
    
    return 0;
}

@implementation FEMSVCRTDLL {
    NSDictionary* _funcToImpMap;
}

- (instancetype)init
{
    self = [super init];
    if (self) {


        _funcToImpMap = @{
                         @"_controlfp": [NSValue valueWithPointer: &fe__controlfp],
                         @"__set_app_type": [NSValue valueWithPointer: &fe___set_app_type],
                         @"__getmainargs": [NSValue valueWithPointer: &fe___getmainargs],
                         @"printf": [NSValue valueWithPointer: &fe_printf],
                         @"exit": [NSValue valueWithPointer: &fe_exit],
                         @"strlen": [NSValue valueWithPointer: &fe_strlen],
                         @"memcpy": [NSValue valueWithPointer: &fe_memcpy]
                         };


    }
    return self;
}

- (NSArray*) funcNames {
    return _funcToImpMap.allKeys;
}

- (BOOL) hasFunctionWithName:(NSString*) funcName {
    return _funcToImpMap[funcName] != nil;
}

- (uint8_t) executeFunctionWithName:(NSString*) funcName process:(FEProcess*) process {
    NSValue* funcPtr = _funcToImpMap[funcName];
    
    if(funcPtr) {
        FEFunctionProxyIMP imp = funcPtr.pointerValue;
        return imp(process);
    }
    assert(false);
    return 0;
}

@end
