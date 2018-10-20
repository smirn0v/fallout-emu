//
//  FEKernel32DLL.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 08/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FEImportsProxy.h"

typedef struct _OSVERSIONINFO {
    uint32_t dwOSVersionInfoSize;
    uint32_t dwMajorVersion;
    uint32_t dwMinorVersion;
    uint32_t dwBuildNumber;
    uint32_t dwPlatformId;
    char szCSDVersion[128];
} OSVERSIONINFO, *POSVERSIONINFO, *LPOSVERSIONINFO;


typedef NS_ENUM(NSUInteger, FEHandleType) {
    kFEHandleType_File,
    kFEHandleType_Mutex,
    kFEHandleType_Module,
    kFEHandleType_IconHandle,
    kFEHandleType_ClassHandle,
    kFEHandleType_WindowHandle,
    kFEHandleType_GDIHandle,
    kFEHandleType_Hook
};

@interface FEKernel32DLL : NSObject<FEDLLProxy>

@property(nonatomic,readwrite) int32_t lastError;

- (uint32_t) createHandleType:(FEHandleType) type name:(NSString*) name payload:(id) payload;
- (NSDictionary*) handleDetails:(uint32_t)handle;
- (void) freeHandle:(uint32_t) handle;

- (BOOL) handle:(uint32_t*) handle withPredicate:(BOOL(^)(NSDictionary*)) predicate;

@end
