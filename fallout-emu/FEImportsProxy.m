//
//  FEImportsProxy.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 01/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEImportsProxy.h"

#include "FEMemoryMap.h"
#include "FEMemoryMapBlock.h"
#import "FEImportException.h"
#import "NSString+FE.h"



#include <sys/types.h>


static const uint32_t kIMAGE_ORDINAL_FLAG32 = 0x80000000;
static NSString* const kDllName = @"dll name";
static NSString* const kFuncName = @"func name";
static const char* const kLoadedStaticImportsMemoryBlock = ".loaded-static-imports";

struct IMAGE_IMPORT_DESCRIPTOR {
    uint32_t originalFirstThunk;
    uint32_t timeDateStamp;
    uint32_t forwarderChain;
    uint32_t importedDLLName;
    uint32_t firstThunk;
};

@implementation FEImportsProxy {
    FEMemoryMap *_memoryMap;
    NSMutableDictionary *_dllsImportMap;
    NSMutableDictionary *_addrToFunction;
    NSMutableDictionary *_proxies;
    FEMemoryMapBlock *_loadedStaticImportsMemoryBlock;
    NSMutableArray* _dynamicImportMemoryBlocks;
}

- (instancetype)initWithMemoryMap:(FEMemoryMap*) memoryMap idataAddress:(uint32_t) idataAddress idataSize:(uint32_t) size imageBase:(uint32_t) imageBase {
    if(self = [super init]) {
        uint32_t impDescAddr = idataAddress;
        struct IMAGE_IMPORT_DESCRIPTOR impDesc;
        fe_memoryMap_memcpyToRealFromVirtual(memoryMap, &impDesc, impDescAddr, sizeof(struct IMAGE_IMPORT_DESCRIPTOR));

        _memoryMap = memoryMap;
        _dllsImportMap = @{}.mutableCopy;
        _addrToFunction = @{}.mutableCopy;
        _proxies = @{}.mutableCopy;
        _dynamicImportMemoryBlocks = @[].mutableCopy;
        
        
        uint32_t importsSize = 0;
        
        while(![self finalImportDescriptor: &impDesc]) {

            char *dllNameCStr;
            fe_memoryMap_strcpyFromVirtualToAllocatedReal(memoryMap, &dllNameCStr, impDesc.importedDLLName + imageBase);
            
            NSString *dllName = [[NSString fe_stringFromASCIIcstr: dllNameCStr] lowercaseString];
            free(dllNameCStr);
            assert(dllName);
            
            if(!_dllsImportMap[dllName]) {
                _dllsImportMap[dllName] = @{}.mutableCopy;
            }
            
            // TODO: use firstThunk in that case.
            assert(impDesc.originalFirstThunk != 0);
            // hope this will never happen :-)
            assert(impDesc.firstThunk != 0);
            
            uint32_t loaded_thunk = impDesc.firstThunk + imageBase;
            uint32_t image_thunk_data_addr = impDesc.originalFirstThunk + imageBase;
            uint32_t image_thunk_data = fe_memoryMap_value32AtAddress(memoryMap, image_thunk_data_addr);

            
            while(image_thunk_data != 0) {
#pragma unused(kIMAGE_ORDINAL_FLAG32)
                // ordinals not supported
                assert(!(image_thunk_data & kIMAGE_ORDINAL_FLAG32));
                
                // skiping hint (hint = 2 bytes)
                uint32_t funcNameAddr = image_thunk_data + 2 + imageBase;
                
                char* funcNameCstr;
                fe_memoryMap_strcpyFromVirtualToAllocatedReal(memoryMap, &funcNameCstr, funcNameAddr);
                
                NSString* funcName = [NSString fe_stringFromASCIIcstr: funcNameCstr];
                
                free(funcNameCstr);
                assert(funcName);
                
                NSMutableArray* loaded_thunks = _dllsImportMap[dllName][funcName];
                if(loaded_thunks == nil) {
                    loaded_thunks = @[].mutableCopy;
                }
                [loaded_thunks addObject: @(loaded_thunk)];
                _dllsImportMap[dllName][funcName] = loaded_thunks;

                image_thunk_data_addr+=4;
                image_thunk_data = fe_memoryMap_value32AtAddress(memoryMap, image_thunk_data_addr);

                loaded_thunk+=4;
                importsSize+=4;
            }

            impDescAddr += sizeof(struct IMAGE_IMPORT_DESCRIPTOR);
            fe_memoryMap_memcpyToRealFromVirtual(memoryMap, &impDesc, impDescAddr, sizeof(struct IMAGE_IMPORT_DESCRIPTOR));
        }
        
        uint32_t importsProxyLinkAddr = fe_memoryMap_malloc(memoryMap, importsSize, kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write, kLoadedStaticImportsMemoryBlock);
        
        _loadedStaticImportsMemoryBlock = fe_memoryMap_blockWithTag(memoryMap, kLoadedStaticImportsMemoryBlock);
        
        for(NSString* dllName in _dllsImportMap) {
            for(NSString* funcName in _dllsImportMap[dllName]) {
                NSArray* loaded_thunks = _dllsImportMap[dllName][funcName];
                for(NSNumber* addrToStoreLink in loaded_thunks) {
                    uint32_t addr = (uint32_t)[addrToStoreLink unsignedIntegerValue];
                    fe_memoryMap_setValue32(memoryMap, addr, importsProxyLinkAddr);
                    _addrToFunction[@(importsProxyLinkAddr)] = @{
                                                                 kDllName: dllName,
                                                                 kFuncName: funcName
                                                                 };
                    importsProxyLinkAddr+=4;
                }
            }
        }
    }
    return self;
}

- (void) registerProxy:(id<FEDLLProxy>) proxy forDLLWithName:(NSString*) dllName {
    if(proxy.funcNames.count == 0) {
        @throw [[FEImportException alloc] initWithName: @"FEImportException"
                                                reason: [NSString stringWithFormat: @"Trying to register proxy for '%@' with no functions", dllName]
                                              userInfo: nil];
    }
    
    _proxies[dllName] = proxy;
}

- (void) loadLibraryNamed:(NSString*) dllName {

    
    id<FEDLLProxy> proxy = _proxies[dllName];
    
    if(!proxy) {
        @throw [[FEImportException alloc] initWithName: @"FEImportException"
                                                reason: [NSString stringWithFormat: @"No proxy for '%@'", dllName]
                                              userInfo: nil];
    }
    
    NSArray *funcNames = proxy.funcNames;
    NSString *tag = [NSString stringWithFormat: @".dynamic-link{%@}", dllName];
    uint32_t mapAddress = fe_memoryMap_malloc(_memoryMap, (uint32_t)funcNames.count*4, 0, [tag cStringUsingEncoding: NSASCIIStringEncoding]);
    
    FEMemoryMapBlock *block = fe_memoryMap_blockWithTag(_memoryMap, [tag cStringUsingEncoding: NSASCIIStringEncoding]);
    [_dynamicImportMemoryBlocks addObject: [NSValue valueWithPointer: block]];
    
    for(NSString *funcName in funcNames) {
        _addrToFunction[@(mapAddress)] = @{
                                           kDllName: dllName,
                                           kFuncName: funcName
                                           };
        mapAddress+=4;
    }
}

- (uint32_t) addressOfFunction:(NSString*) funcName fromDLL:(NSString*) dllName {

    for(NSNumber* addr in _addrToFunction) {
        NSString* itDllName = _addrToFunction[addr][kDllName];
        NSString* itFuncName = _addrToFunction[addr][kFuncName];
        
        if([itDllName isEqualToString: dllName] && [itFuncName isEqualToString: funcName]) {
            return (uint32_t)addr.unsignedIntegerValue;
        }
    }
    NSString *reason = [NSString stringWithFormat: @"%@:%@ was not imported",dllName, funcName];
    @throw [[FEImportException alloc] initWithName: @"FEImportException"
                                            reason: reason
                                          userInfo: nil];
}

- (id<FEDLLProxy>) proxyForDLLName:(NSString*) dllName {
    return _proxies[dllName];
}

- (BOOL) isAddressWithinLoadedImports:(uint32_t) address {
    if(fe_memoryMapBlock_containsVirtualAddress(_loadedStaticImportsMemoryBlock, address)) {
        return YES;
    } else {
        for(NSValue *blockValue in _dynamicImportMemoryBlocks) {
            FEMemoryMapBlock *block = (FEMemoryMapBlock*)[blockValue pointerValue];
            if(fe_memoryMapBlock_containsVirtualAddress(block, address)) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSString*) functionDescriptionFromAddress:(uint32_t) address {
    if(![self isAddressWithinLoadedImports: address]) {
        return @"{no function found}";
    }
    
    NSDictionary* proxyCoordinates = _addrToFunction[@(address)];
    
    if(proxyCoordinates) {
        NSString* dllName = proxyCoordinates[kDllName];
        NSString* funcName = proxyCoordinates[kFuncName];
        
        
        return [NSString stringWithFormat: @"{%@:%@}",dllName,funcName];
    }
    
    return @"{no function found}";
}

- (uint8_t) executeFunctionAtAddress:(uint32_t) address withinProcess:(FEProcess*)process {
    
    if(![self isAddressWithinLoadedImports: address]) {
        @throw [[FEImportException alloc] initWithName: @"FEImportException"
                                                reason: @"Trying to get imp of imported function for address that is not related to imports"
                                              userInfo: nil];
    }
    
    NSDictionary* proxyCoordinates = _addrToFunction[@(address)];
    
    if(proxyCoordinates) {
        NSString* dllName = proxyCoordinates[kDllName];
        NSString* funcName = proxyCoordinates[kFuncName];
        
        id<FEDLLProxy> proxy = _proxies[dllName];
        if(![proxy hasFunctionWithName: funcName]) {
            NSString* reason = [NSString stringWithFormat: @"No implementation for function '%@' from '%@'", funcName, dllName];
            @throw [[FEImportException alloc] initWithName: @"FEImportException"
                                                    reason: reason
                                                  userInfo: nil];
        }
        
        
        return [proxy executeFunctionWithName: funcName process: process];
    }
    
    return 0;
}

#pragma mark - Private

- (BOOL) finalImportDescriptor:(struct IMAGE_IMPORT_DESCRIPTOR*) impDesc {
    return impDesc->originalFirstThunk == 0 &&
           impDesc->timeDateStamp == 0 &&
           impDesc->forwarderChain == 0 &&
           impDesc->importedDLLName == 0 &&
           impDesc->firstThunk == 0;
}

@end
