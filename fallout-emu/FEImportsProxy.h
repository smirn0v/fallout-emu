//
//  FEImportsProxy.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 01/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "FEMemoryMap.h"


@class FEImportsProxy;
@class FEProcess;

typedef uint8_t(*FEFunctionProxyIMP)(FEProcess*);

@protocol FEDLLProxy<NSObject>

- (NSArray*) funcNames;
- (BOOL) hasFunctionWithName:(NSString*) funcName;
- (uint8_t) executeFunctionWithName:(NSString*) funcName process:(FEProcess*) process;

@end

@interface FEImportsProxy : NSObject

- (instancetype)initWithMemoryMap:(FEMemoryMap*) memoryMap idataAddress:(uint32_t) idataAddress idataSize:(uint32_t) size imageBase:(uint32_t) imageBase;
- (void) registerProxy:(id<FEDLLProxy>) proxy forDLLWithName:(NSString*) dllName;
- (void) loadLibraryNamed:(NSString*) dllName;
- (uint32_t) addressOfFunction:(NSString*) funcName fromDLL:(NSString*) dllName;
- (id<FEDLLProxy>) proxyForDLLName:(NSString*) dllName;
- (BOOL) isAddressWithinLoadedImports:(uint32_t) address;
- (NSString*) functionDescriptionFromAddress:(uint32_t) address;
- (uint8_t) executeFunctionAtAddress:(uint32_t) address withinProcess:(FEProcess*)process;

@end
