//
//  FEWinmmDLL.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 31/05/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEWinmmDLL.h"
#import "FEProcess.h"


static uint8_t fe_timeGetTime(FEProcess *process) {
    
    id<FEDLLProxy> proxy = [process.importsProxy proxyForDLLName:@"kernel32.dll"];
    
    return [proxy executeFunctionWithName:@"GetTickCount" process: process];
}

@implementation FEWinmmDLL {
    NSDictionary* _funcToImpMap;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _funcToImpMap = @{
                          @"timeGetTime": [NSValue valueWithPointer: &fe_timeGetTime]
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
