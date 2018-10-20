//
//  FEProcess.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 14/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <inttypes.h>
#include "FEMemoryMap.h"
#include "FELocalDescriptorTable.h"

@class FEProcess;
@class FEImportsProxy;


typedef struct FEThreadContext FEThreadContext;

typedef struct FEProcessContext {
    FEMemoryMap *memory;
    FELocalDescriptorTable *ldt;
    FEThreadContext *currentThread;
} FEProcessContext;


@interface FEProcess : NSObject

@property(nonatomic,readonly) NSString *path;
@property(nonatomic,readonly) NSString *diskCPath;
@property(nonatomic,readonly) NSString *currentRealPath;
@property(nonatomic,readonly) FEMemoryMap *memory;
@property(nonatomic,readonly) FELocalDescriptorTable *ldt;
@property(nonatomic,readonly) FEImportsProxy *importsProxy;
// threads contexts
@property(nonatomic,readonly) NSArray *threads;

@property(nonatomic,readonly) FEThreadContext *mainThread;
@property(nonatomic,readonly) FEThreadContext *currentThread;

@property(nonatomic,readonly) uint64_t instrPerMillisecond;
@property(nonatomic,readonly) uint64_t instrCounter;


@property(nonatomic,readonly) NSArray *instructionsUsageFrequency;
@property(nonatomic,assign) uint64_t logInstructionsAfter;
@property(nonatomic,assign) BOOL recordInstructionsUsageFrequency;
@property(nonatomic,assign) BOOL logInstructions;
@property(nonatomic,assign) BOOL logExternalCalls;
@property(nonatomic,assign) BOOL printStdOut;

- (instancetype)initWithPathToExecutable:(NSString*) path diskCPath:(NSString*) diskCPath;



- (void) addThread:(FEThreadContext*) threadContext;
- (void) removeThread:(FEThreadContext*) threadContext;

- (uint32_t) run;
- (void) exit:(uint32_t) code;

- (NSString*) stdoutBuffer;
- (void) addToStdout:(NSString*) str;

@end
