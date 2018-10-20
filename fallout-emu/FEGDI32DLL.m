//
//  FEGDI32DLL.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 29/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEGDI32DLL.h"
#include "FEThreadContext.h"
#import "FEKernel32DLL.h"
#include "FEMemoryMap.h"
#import "FEStack.h"
#import "FEProcess.h"

@interface FEGDI32DLL()

@end

/*
 HGDIOBJ GetStockObject(
 _In_  int fnObject
 );
 */
static uint8_t fe_GetStockObject(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t fnObject = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    assert(fnObject == BLACK_BRUSH);
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    assert(kernel32);
    
    uint32_t brush_handle = [kernel32 createHandleType: kFEHandleType_GDIHandle name: @"black-brush" payload:@{
                                                                                                               @"object": @(fnObject)
                                                                                                               }];
    
    process.currentThread->eax = brush_handle;
    
    return 4;
}

@implementation FEGDI32DLL {
    NSDictionary* _funcToImpMap;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
    
        _funcToImpMap = @{
                         @"GetStockObject": [NSValue valueWithPointer: &fe_GetStockObject]
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
