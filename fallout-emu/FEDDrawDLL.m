
//
//  FEDDrawDLL.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 29/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEDDrawDLL.h"
#import "FEUser32DLL.h"
#include "FEThreadContext.h"
#include "FEMemoryMap.h"
#import "FEStack.h"
#import "FEProcess.h"

@interface FEDDrawDLL()

@property(nonatomic,readwrite) uint32_t ddvmt;
@property(nonatomic,readwrite) uint32_t width;
@property(nonatomic,readwrite) uint32_t height;
@property(nonatomic,readwrite) uint32_t bpp;
@property(nonatomic,readwrite) uint32_t refreshRate;
@property(nonatomic,readwrite) uint32_t flags;
@property(nonatomic,readonly) NSMutableDictionary *surfaces;

- (void) enumerateDelegatesWithSelector:(SEL) selector block:(void(^)(id<FEDDrawDLLDelegate>))block;


@end


BOOL CGImageWriteToFile(CGImageRef image, NSString *path) {
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    if (!destination) {
        NSLog(@"Failed to create CGImageDestination for %@", path);
        return NO;
    }
    
    CGImageDestinationAddImage(destination, image, nil);
    
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to write image to %@", path);
        CFRelease(destination);
        return NO;
    }
    
    CFRelease(destination);
    return YES;
}

/*
 HRESULT WINAPI DirectDrawCreate(
 _In_   GUID FAR *lpGUID,
 _Out_  LPDIRECTDRAW FAR *lplpDD,
 _In_   IUnknown FAR *pUnkOuter
 );
 */

static uint8_t fe_DirectDrawCreate(FEProcess *process) {
    
    FEDDrawDLL *ddraw = [process.importsProxy proxyForDLLName: @"ddraw.dll"];
    
#pragma unused(ddraw)
    
    assert(ddraw.ddvmt == 0);//can't create two DD contexts
    
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpGUID = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lplpDD = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_pUnkOuter = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
    if(process.logExternalCalls) {
        printf("lpGUID = 0x%x, lplpDD = 0x%x, pUnkOuter = 0x%x\n", arg_lpGUID, arg_lplpDD, arg_pUnkOuter);
    }
    
    IDirectDrawVMT ddvmt;
    
    ddvmt.QueryInterface = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::QueryInterface" fromDLL: @"ddraw.dll"];
    ddvmt.AddRef = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::AddRef" fromDLL:@"ddraw.dll"];
    ddvmt.Release = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::Release" fromDLL:@"ddraw.dll"];
    ddvmt.Compact = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::Compact" fromDLL:@"ddraw.dll"];
    ddvmt.CreateClipper = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::CreateClipper" fromDLL:@"ddraw.dll"];
    ddvmt.CreatePalette = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::CreatePalette" fromDLL:@"ddraw.dll"];
    ddvmt.CreateSurface = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::CreateSurface" fromDLL:@"ddraw.dll"];
    ddvmt.DuplicateSurface = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::DuplicateSurface" fromDLL:@"ddraw.dll"];
    ddvmt.EnumDisplayModes = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::EnumDisplayModes" fromDLL:@"ddraw.dll"];
    ddvmt.EnumSurfaces = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::EnumSurfaces" fromDLL:@"ddraw.dll"];
    ddvmt.FlipToGDISurface = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::FlipToGDISurface" fromDLL: @"ddraw.dll"];
    ddvmt.GetCaps = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::GetCaps" fromDLL:@"ddraw.dll"];
    ddvmt.GetDisplayMode = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::GetDisplayMode" fromDLL:@"ddraw.dll"];
    ddvmt.GetFourCCCodes = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::GetFourCCCodes" fromDLL:@"ddraw.dll"];
    ddvmt.GetGDISurface = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::GetGDISurface" fromDLL:@"ddraw.dll"];
    ddvmt.GetMonitorFrequency = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::GetMonitorFrequency" fromDLL:@"ddraw.dll"];
    ddvmt.GetScanLine = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::GetScanLine" fromDLL:@"ddraw.dll"];
    ddvmt.GetVerticalBlankStatus = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::GetVerticalBlankStatus" fromDLL:@"ddraw.dll"];
    ddvmt.Initialize = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::Initialize" fromDLL:@"ddraw.dll"];
    ddvmt.RestoreDisplayMode = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::RestoreDisplayMode" fromDLL:@"ddraw.dll"];
    ddvmt.SetCooperativeLevel = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::SetCooperativeLevel" fromDLL:@"ddraw.dll"];
    ddvmt.SetDisplayMode = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::SetDisplayMode" fromDLL:@"ddraw.dll"];
    ddvmt.WaitForVerticalBlank = [process.importsProxy addressOfFunction:@"IDirectDrawVMT::WaitForVerticalBlank" fromDLL:@"ddraw.dll"];

    uint32_t vddvmt = fe_memoryMap_malloc(process.memory, sizeof(IDirectDrawVMT), kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[ @"IDirectDrawVMT" cStringUsingEncoding: NSASCIIStringEncoding]);
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,  vddvmt,  &ddvmt, sizeof(IDirectDrawVMT));
    
    IDirectDraw dd = { .VMT = vddvmt };
    
    uint32_t vdd = fe_memoryMap_malloc(process.memory, sizeof(IDirectDraw), kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write,[ @"IDirectDraw" cStringUsingEncoding: NSASCIIStringEncoding]);

    fe_memoryMap_memcpyToVirtualFromReal(process.memory, vdd, &dd, sizeof(IDirectDraw));
    fe_memoryMap_setValue32(process.memory, arg_lplpDD, vdd);
    
    process.currentThread->eax = 0;;
    
    return 12;
}

static uint8_t fe_IDirectDrawVMT_QueryInterface(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_AddRef(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_Release(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_Compact(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_CreateClipper(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT CreatePalette(

 [in]  DWORD                   dwFlags,
 [in]  LPPALETTEENTRY          lpDDColorArray,
 [out] LPDIRECTDRAWPALETTE FAR *lplpDDPalette,
 [in]  IUnknown FAR            *pUnkOuter
 );
 */
static uint8_t fe_IDirectDrawVMT_CreatePalette(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    //uint32_t arg_ddvmt = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_dwFlags = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lpDDColorArray = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_lplpDDPalette = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
#pragma unused(arg_dwFlags)
    
    assert(arg_dwFlags == 0x44);//256 palette entries
    
    PALETTEENTRY paletteEntries[256];
    uint32_t entryAddress = arg_lpDDColorArray;
    for(int i = 0;i<256;i++) {
        
        fe_memoryMap_memcpyToRealFromVirtual(process.memory, &paletteEntries[i], entryAddress, sizeof(PALETTEENTRY));

        entryAddress += sizeof(PALETTEENTRY);
    }
    //XXX save palette
    
    IDirectDrawPalette paletteObj;
    paletteObj.QueryInterface = [process.importsProxy addressOfFunction:@"IDirectDrawPalette::QueryInterface" fromDLL:@"ddraw.dll"];
    paletteObj.AddRef = [process.importsProxy addressOfFunction:@"IDirectDrawPalette::AddRef" fromDLL:@"ddraw.dll"];
    paletteObj.Release = [process.importsProxy addressOfFunction:@"IDirectDrawPalette::Release" fromDLL:@"ddraw.dll"];
    paletteObj.GetCaps = [process.importsProxy addressOfFunction:@"IDirectDrawPalette::GetCaps" fromDLL:@"ddraw.dll"];
    paletteObj.GetEntries = [process.importsProxy addressOfFunction:@"IDirectDrawPalette::GetEntries" fromDLL:@"ddraw.dll"];
    paletteObj.Initialize = [process.importsProxy addressOfFunction:@"IDirectDrawPalette::Initialize" fromDLL:@"ddraw.dll"];
    paletteObj.SetEntries = [process.importsProxy addressOfFunction:@"IDirectDrawPalette::SetEntries" fromDLL:@"ddraw.dll"];
    
    uint32_t vpaletteObj = fe_memoryMap_malloc(process.memory, sizeof(IDirectDrawPalette),kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[@"IDirectDrawPalette" cStringUsingEncoding: NSASCIIStringEncoding]);
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, vpaletteObj, &paletteObj, sizeof(IDirectDrawPalette));
    
    uint32_t vptrpaletteObj = fe_memoryMap_malloc(process.memory, 4,kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[@"ptr to IDirectDrawPalette" cStringUsingEncoding: NSASCIIStringEncoding]);
    
    fe_memoryMap_setValue32(process.memory,vptrpaletteObj,vpaletteObj);
    
    fe_memoryMap_setValue32(process.memory,arg_lplpDDPalette,vptrpaletteObj);
    
    process.currentThread->eax = 0;;
    
    return 20;
}


/*
 HRESULT CreateSurface(

 [in]  LPDDSURFACEDESC         lpDDSurfaceDesc,
 [out] LPDIRECTDRAWSURFACE7 FAR *lplpDDSurface,
 [in]  IUnknown FAR             *pUnkOuter
 );
 */
static uint8_t fe_IDirectDrawVMT_CreateSurface(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    //uint32_t arg_ddvmt = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpDDSurfaceDesc = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lplpDDSurface = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    //uint32_t arg_pUnkOuter = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
    DDSURFACEDESC surfaceDesc;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory, &surfaceDesc, arg_lpDDSurfaceDesc, sizeof(DDSURFACEDESC));
    
    IDirectDrawSurface7 surfaceObj;
    surfaceObj.QueryInterface=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::QueryInterface" fromDLL:@"ddraw.dll"];
    surfaceObj.AddRef=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::AddRef" fromDLL:@"ddraw.dll"];
    surfaceObj.Release=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::Release" fromDLL:@"ddraw.dll"];
    surfaceObj.AddAttachedSurface=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::AddAttachedSurface" fromDLL:@"ddraw.dll"];
    surfaceObj.AddOverlayDirtyRect=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::AddOverlayDirtyRect" fromDLL:@"ddraw.dll"];
    surfaceObj.Blt=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::Blt" fromDLL:@"ddraw.dll"];
    surfaceObj.BltBatch=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::BltBatch" fromDLL:@"ddraw.dll"];
    surfaceObj.BltFast=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::BltFast" fromDLL:@"ddraw.dll"];
    surfaceObj.DeleteAttachedSurface=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::DeleteAttachedSurface" fromDLL:@"ddraw.dll"];
    surfaceObj.EnumAttachedSurfaces=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::EnumAttachedSurfaces" fromDLL:@"ddraw.dll"];
    surfaceObj.EnumOverlayZOrders=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::EnumOverlayZOrders" fromDLL:@"ddraw.dll"];
    surfaceObj.Flip=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::Flip" fromDLL:@"ddraw.dll"];
    surfaceObj.GetAttachedSurface=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetAttachedSurface" fromDLL:@"ddraw.dll"];
    surfaceObj.GetBltStatus=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetBltStatus" fromDLL:@"ddraw.dll"];
    surfaceObj.GetCaps=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetCaps" fromDLL:@"ddraw.dll"];
    surfaceObj.GetClipper=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetClipper" fromDLL:@"ddraw.dll"];
    surfaceObj.GetColorKey=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetColorKey" fromDLL:@"ddraw.dll"];
    surfaceObj.GetDC=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetDC" fromDLL:@"ddraw.dll"];
    surfaceObj.GetFlipStatus=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetFlipStatus" fromDLL:@"ddraw.dll"];
    surfaceObj.GetOverlayPosition=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetOverlayPosition" fromDLL:@"ddraw.dll"];
    surfaceObj.GetPalette=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetPalette" fromDLL:@"ddraw.dll"];
    surfaceObj.GetPixelFormat=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetPixelFormat" fromDLL:@"ddraw.dll"];
    surfaceObj.GetSurfaceDesc=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetSurfaceDesc" fromDLL:@"ddraw.dll"];
    surfaceObj.Initialize=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::Initialize" fromDLL:@"ddraw.dll"];
    surfaceObj.IsLost=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::IsLost" fromDLL:@"ddraw.dll"];
    surfaceObj.Lock=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::Lock" fromDLL:@"ddraw.dll"];
    surfaceObj.ReleaseDC=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::ReleaseDC" fromDLL:@"ddraw.dll"];
    surfaceObj.Restore=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::Restore" fromDLL:@"ddraw.dll"];
    surfaceObj.SetClipper=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::SetClipper" fromDLL:@"ddraw.dll"];
    surfaceObj.SetColorKey=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::SetColorKey" fromDLL:@"ddraw.dll"];
    surfaceObj.SetOverlayPosition=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::SetOverlayPosition" fromDLL:@"ddraw.dll"];
    surfaceObj.SetPalette=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::SetPalette" fromDLL:@"ddraw.dll"];
    surfaceObj.Unlock=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::Unlock" fromDLL:@"ddraw.dll"];
    surfaceObj.UpdateOverlay=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::UpdateOverlay" fromDLL:@"ddraw.dll"];
    surfaceObj.UpdateOverlayDisplay=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::UpdateOverlayDisplay" fromDLL:@"ddraw.dll"];
    surfaceObj.UpdateOverlayZOrder=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::UpdateOverlayZOrder" fromDLL:@"ddraw.dll"];
    surfaceObj.GetDDInterface=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetDDInterface" fromDLL:@"ddraw.dll"];
    surfaceObj.PageLock=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::PageLock" fromDLL:@"ddraw.dll"];
    surfaceObj.PageUnlock=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::PageUnlock" fromDLL:@"ddraw.dll"];
    surfaceObj.SetSurfaceDesc=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::SetSurfaceDesc" fromDLL:@"ddraw.dll"];
    surfaceObj.SetPrivateData=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::SetPrivateData" fromDLL:@"ddraw.dll"];
    surfaceObj.GetPrivateData=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetPrivateData" fromDLL:@"ddraw.dll"];
    surfaceObj.FreePrivateData=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::FreePrivateData" fromDLL:@"ddraw.dll"];
    surfaceObj.GetUniquenessValue=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetUniquenessValue" fromDLL:@"ddraw.dll"];
    surfaceObj.ChangeUniquenessValue=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::ChangeUniquenessValue" fromDLL:@"ddraw.dll"];
    surfaceObj.SetPriority=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::SetPriority" fromDLL:@"ddraw.dll"];
    surfaceObj.GetPriority=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetPriority" fromDLL:@"ddraw.dll"];
    surfaceObj.SetLOD=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::SetLOD" fromDLL:@"ddraw.dll"];
    surfaceObj.GetLOD=[process.importsProxy addressOfFunction:@"IDirectDrawSurface7::GetLOD" fromDLL:@"ddraw.dll"];
    
    uint32_t vsurfaceObj = fe_memoryMap_malloc(process.memory, sizeof(IDirectDrawSurface7), kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[ @"IDirectDrawSurface7" cStringUsingEncoding: NSASCIIStringEncoding]);
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, vsurfaceObj, &surfaceObj, sizeof(IDirectDrawSurface7));
    
    uint32_t vptrsurfaceObj = fe_memoryMap_malloc(process.memory, 4, kFEMemoryAccessMode_Read| kFEMemoryAccessMode_Write, "ptr to IDirectDrawSurface7");
    
    fe_memoryMap_setValue32(process.memory,vptrsurfaceObj,vsurfaceObj);
    
    fe_memoryMap_setValue32(process.memory,arg_lplpDDSurface,vptrsurfaceObj);
    
    
    FEDDrawDLL *ddraw = [process.importsProxy proxyForDLLName: @"ddraw.dll"];
    
    surfaceDesc.dwWidth = ddraw.width;
    surfaceDesc.dwHeight = ddraw.height;
    surfaceDesc.lPitch = ddraw.width * ddraw.bpp/8;//no need for stride

    
    surfaceDesc.lpSurface = fe_memoryMap_malloc(process.memory, ddraw.width*ddraw.height*ddraw.bpp/8, kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[ @"Surface backing memory" cStringUsingEncoding: NSASCIIStringEncoding]);
    
    ddraw.surfaces[@(vptrsurfaceObj)] = [NSValue valueWithBytes: &surfaceDesc objCType: @encode(DDSURFACEDESC)];
    
    process.currentThread->eax = 0;;
    
    return 16;
}

static uint8_t fe_IDirectDrawVMT_DuplicateSurface(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_EnumDisplayModes(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_EnumSurfaces(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_FlipToGDISurface(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_GetCaps(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_GetDisplayMode(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_GetFourCCCodes(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_GetGDISurface(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_GetMonitorFrequency(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_GetScanLine(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_GetVerticalBlankStatus(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawVMT_Initialize(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT RestoreDisplayMode();
 */
static uint8_t fe_IDirectDrawVMT_RestoreDisplayMode(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT SetCooperativeLevel(
 uint32_t IDirectDrawVMT
 [in] HWND  hWnd,
 [in] DWORD dwFlags
 );

 */
static uint8_t fe_IDirectDrawVMT_SetCooperativeLevel(FEProcess *process) {
    process.currentThread->eax = 0;;
    return 12;
}

/*
 HRESULT SetDisplayMode(
 [in] DWORD dwWidth,
 [in] DWORD dwHeight,
 [in] DWORD dwBPP,
 );
 */
static uint8_t fe_IDirectDrawVMT_SetDisplayMode(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_ddvmt = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_width = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_height = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_bpp = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
    if(process.logExternalCalls) {
        printf("ddvmt = 0x%x, width = %u, height = %u, bpp = %u\n", arg_ddvmt, arg_width, arg_height, arg_bpp);
    }
    
    process.currentThread->eax = 0;;
    
    FEDDrawDLL *ddraw = [process.importsProxy proxyForDLLName: @"ddraw.dll"];
    ddraw.width = arg_width;
    ddraw.height = arg_height;
    ddraw.bpp = arg_bpp;
    
    return 16;
}

static uint8_t fe_IDirectDrawVMT_WaitForVerticalBlank(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawSurface7_QueryInterface(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_AddRef(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawSurface7_Release(FEProcess *process) {
    process.currentThread->eax = 0;
    return 4;
}
static uint8_t fe_IDirectDrawSurface7_AddAttachedSurface(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_AddOverlayDirtyRect(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT Blt(
 LPRECT lpDestRect,
 LPDIRECTDRAWSURFACE lpDDSrcSurface,
 LPRECT lpSrcRect,
 DWORD dwFlags,
 LPDDBLTFX lpDDBltFx
 );
 */
static uint8_t fe_IDirectDrawSurface7_Blt(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpDestRect = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lpDDSrcSurface = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_lpSrcRect = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    uint32_t arg_dwFlags = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
    uint32_t arg_lpDDBltFx = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+20);
    
    if(process.logExternalCalls) {
        NSLog(@"this = 0x%X, dest rect = 0x%X, src surf = 0x%X, src rect = 0x%X, flags = 0x%X, bltfx = 0x%X", arg_this, arg_lpDestRect, arg_lpDDSrcSurface, arg_lpSrcRect, arg_dwFlags, arg_lpDDBltFx);
    }
    
    RECT destRect, srcRect;
    if(arg_lpDestRect) {
        fe_memoryMap_memcpyToRealFromVirtual(process.memory, &destRect, arg_lpDestRect, sizeof(RECT));
    }
    
    if(arg_lpSrcRect) {
        fe_memoryMap_memcpyToRealFromVirtual(process.memory, &srcRect, arg_lpSrcRect, sizeof(RECT));
    }
    
    if(process.logExternalCalls) {
        NSLog(@"dst rect %d %d %d %d",destRect.bottom, destRect.left, destRect.right, destRect.top);
        NSLog(@"src rect %d %d %d %d",srcRect.bottom, srcRect.left, srcRect.right, srcRect.top);
    }
    FEDDrawDLL *ddraw = [process.importsProxy proxyForDLLName: @"ddraw.dll"];
    
    NSValue *surfaceDescValue =  ddraw.surfaces[@(arg_lpDDSrcSurface)];// = [NSValue valueWithBytes: &surfaceDesc objCType: @encode(DDSURFACEDESC)];
    DDSURFACEDESC srcSurfaceDescription;
    [surfaceDescValue getValue: &srcSurfaceDescription];
    
    if(process.logExternalCalls) {
        NSLog(@"Src size %d %d, address = 0x%X", srcSurfaceDescription.dwWidth, srcSurfaceDescription.dwHeight, srcSurfaceDescription.lpSurface);
    }
    
    //char *converted = malloc(srcSurfaceDescription.dwWidth*srcSurfaceDescription.dwHeight * 3);//3 bytes per pixel
    
    FEMemoryMapBlock *mBlock = fe_memoryMap_blockFromVirtualAddress(process.memory, srcSurfaceDescription.lpSurface);
    void *original = (char*)(mBlock->localAddress) + (srcSurfaceDescription.lpSurface - mBlock->virtualAddress);
    // uint32_t i = 0;
//    char *byte = original;
//    for(;i<srcSurfaceDescription.dwWidth*srcSurfaceDescription.dwHeight;i++,byte++,converted+=3) {
//        *converted = *byte;
//        *(converted+1) = *byte;
//        *(converted+2) = *byte;
//    }
    
    static uint64_t frame_n = 0;
    
    
    //NSData *convertedData = [NSData dataWithBytesNoCopy:converted length:srcSurfaceDescription.dwWidth*srcSurfaceDescription.dwHeight * 3 freeWhenDone:NO];
    NSData *originalData = [NSData dataWithBytesNoCopy:original length:srcSurfaceDescription.dwWidth*srcSurfaceDescription.dwHeight freeWhenDone:NO];
    
    
    [ddraw enumerateDelegatesWithSelector: @selector(feddrawdllNewData:) block:^(id<FEDDrawDLLDelegate> delegate) {
        [delegate feddrawdllNewData: originalData];
    }];
    
    // [convertedData writeToFile:[NSString stringWithFormat:@"/Users/smirnov/frames/%lld.converted", frame_n] atomically:YES];
    //[originalData writeToFile:[NSString stringWithFormat:@"/Users/smirnov/frames/%lld.original", frame_n] atomically:YES];
//    
//    CGColorSpaceRef colorSpace =  CGColorSpaceCreateDeviceRGB();
//    CGDataProviderRef dataProvider =  CGDataProviderCreateWithData(NULL,converted,srcSurfaceDescription.dwWidth*srcSurfaceDescription.dwHeight * 3, NULL);
//    
//    CGImageRef image =  CGImageCreate(srcSurfaceDescription.dwWidth, srcSurfaceDescription.dwHeight, 8, 24, srcSurfaceDescription.dwWidth*3, colorSpace, kCGBitmapByteOrderDefault, dataProvider, NULL, false, kCGRenderingIntentDefault);
//    
//    
//    
//    CGImageWriteToFile(image, [NSString stringWithFormat:@"/Users/smirnov/frames/%lld.png", frame_n]);
//    
//    CGImageRelease(image);
//    
//    CGDataProviderRelease(dataProvider);
//    CGColorSpaceRelease(colorSpace);
    
    frame_n++;
    
    // free(converted);
    
    process.currentThread->eax = 0;
    return 24;
}
static uint8_t fe_IDirectDrawSurface7_BltBatch(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_BltFast(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_DeleteAttachedSurface(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_EnumAttachedSurfaces(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_EnumOverlayZOrders(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_Flip(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetAttachedSurface(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetBltStatus(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetCaps(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetClipper(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetColorKey(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetDC(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetFlipStatus(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetOverlayPosition(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetPalette(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetPixelFormat(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetSurfaceDesc(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_Initialize(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_IsLost(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT Lock(
 LPRECT lpDestRect,
 LPDDSURFACEDESC lpDDSurfaceDesc,
 DWORD dwFlags,
 HANDLE hEvent
 );
 */
static uint8_t fe_IDirectDrawSurface7_Lock(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_surface = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpDestRect = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lpDDSurfaceDesc = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_dwFlags = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    uint32_t arg_hEvent = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
    
    RECT rect = {0,0,0,0};
    if(arg_lpDestRect) {
        fe_memoryMap_memcpyToRealFromVirtual(process.memory, &rect, arg_lpDestRect, sizeof(RECT));
    }
    
    FEDDrawDLL *ddraw = [process.importsProxy proxyForDLLName: @"ddraw.dll"];
    
    NSValue* surfaceDesc = ddraw.surfaces[@(arg_surface)];
    assert(surfaceDesc);
    DDSURFACEDESC surfaceDescStruct;
    [surfaceDesc getValue: &surfaceDescStruct];
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, arg_lpDDSurfaceDesc, &surfaceDescStruct, sizeof(DDSURFACEDESC));
    
    if(process.logExternalCalls) {
        NSLog(@"surface = 0x%X, flags = 0x%X, event = 0x%X", arg_surface, arg_dwFlags, arg_hEvent);
    }
    
    
    
    process.currentThread->eax = 0;
    
    return 20;
}
static uint8_t fe_IDirectDrawSurface7_ReleaseDC(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_Restore(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_SetClipper(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_SetColorKey(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_SetOverlayPosition(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT SetPalette(

 [in] LPDIRECTDRAWPALETTE FAR lpDDPalette
 );

 */
static uint8_t fe_IDirectDrawSurface7_SetPalette(FEProcess *process) {
    //uint32_t ptrToArgs = process.currentThread->esp+4;
    
    //uint32_t arg_surface = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    //uint32_t arg_lpDDPalette = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    //XXX save palette
    process.currentThread->eax = 0;;
    
    return 8;
}

/*
 HRESULT Unlock(
 LPRECT lpRect
 );
 */
static uint8_t fe_IDirectDrawSurface7_Unlock(FEProcess *process) {
    process.currentThread->eax = 0;
    return 8;
}
static uint8_t fe_IDirectDrawSurface7_UpdateOverlay(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_UpdateOverlayDisplay(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_UpdateOverlayZOrder(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetDDInterface(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_PageLock(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_PageUnlock(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_SetSurfaceDesc(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_SetPrivateData(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetPrivateData(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_FreePrivateData(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetUniquenessValue(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_ChangeUniquenessValue(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_SetPriority(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetPriority(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_SetLOD(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawSurface7_GetLOD(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectDrawPalette_QueryInterface(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawPalette_AddRef(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawPalette_Release(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawPalette_GetCaps(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawPalette_GetEntries(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectDrawPalette_Initialize(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT SetEntries(
 [in] DWORD          dwFlags,
 [in] DWORD          dwStartingEntry,
 [in] DWORD          dwCount,
 [in] LPPALETTEENTRY lpEntries
 );
 */
static uint8_t fe_IDirectDrawPalette_SetEntries(FEProcess *process) {
    process.currentThread->eax = 0;;
    return 20;
}


@implementation FEDDrawDLL {
    NSDictionary *_funcToImpMap;
    NSHashTable *_delegates;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _delegates = [NSHashTable hashTableWithOptions: NSPointerFunctionsWeakMemory];
        _surfaces = @{}.mutableCopy;
    
        _funcToImpMap = @{
                         @"DirectDrawCreate": [NSValue valueWithPointer: &fe_DirectDrawCreate],
                         @"IDirectDrawVMT::QueryInterface": [NSValue valueWithPointer: &fe_IDirectDrawVMT_QueryInterface],
                         @"IDirectDrawVMT::AddRef": [NSValue valueWithPointer: &fe_IDirectDrawVMT_AddRef],
                         @"IDirectDrawVMT::Release": [NSValue valueWithPointer: &fe_IDirectDrawVMT_Release],
                         @"IDirectDrawVMT::Compact": [NSValue valueWithPointer: &fe_IDirectDrawVMT_Compact],
                         @"IDirectDrawVMT::CreateClipper": [NSValue valueWithPointer: &fe_IDirectDrawVMT_CreateClipper],
                         @"IDirectDrawVMT::CreatePalette": [NSValue valueWithPointer: &fe_IDirectDrawVMT_CreatePalette],
                         @"IDirectDrawVMT::CreateSurface": [NSValue valueWithPointer: &fe_IDirectDrawVMT_CreateSurface],
                         @"IDirectDrawVMT::DuplicateSurface": [NSValue valueWithPointer: &fe_IDirectDrawVMT_DuplicateSurface],
                         @"IDirectDrawVMT::EnumDisplayModes": [NSValue valueWithPointer: &fe_IDirectDrawVMT_EnumDisplayModes],
                         @"IDirectDrawVMT::EnumSurfaces": [NSValue valueWithPointer: &fe_IDirectDrawVMT_EnumSurfaces],
                         @"IDirectDrawVMT::FlipToGDISurface": [NSValue valueWithPointer: &fe_IDirectDrawVMT_FlipToGDISurface],
                         @"IDirectDrawVMT::GetCaps": [NSValue valueWithPointer: &fe_IDirectDrawVMT_GetCaps],
                         @"IDirectDrawVMT::GetDisplayMode": [NSValue valueWithPointer: &fe_IDirectDrawVMT_GetDisplayMode],
                         @"IDirectDrawVMT::GetFourCCCodes": [NSValue valueWithPointer: &fe_IDirectDrawVMT_GetFourCCCodes],
                         @"IDirectDrawVMT::GetGDISurface": [NSValue valueWithPointer: &fe_IDirectDrawVMT_GetGDISurface],
                         @"IDirectDrawVMT::GetMonitorFrequency": [NSValue valueWithPointer: &fe_IDirectDrawVMT_GetMonitorFrequency],
                         @"IDirectDrawVMT::GetScanLine": [NSValue valueWithPointer: &fe_IDirectDrawVMT_GetScanLine],
                         @"IDirectDrawVMT::GetVerticalBlankStatus": [NSValue valueWithPointer: &fe_IDirectDrawVMT_GetVerticalBlankStatus],
                         @"IDirectDrawVMT::Initialize": [NSValue valueWithPointer: &fe_IDirectDrawVMT_Initialize],
                         @"IDirectDrawVMT::RestoreDisplayMode": [NSValue valueWithPointer: &fe_IDirectDrawVMT_RestoreDisplayMode],
                         @"IDirectDrawVMT::SetCooperativeLevel": [NSValue valueWithPointer: &fe_IDirectDrawVMT_SetCooperativeLevel],
                         @"IDirectDrawVMT::SetDisplayMode": [NSValue valueWithPointer: &fe_IDirectDrawVMT_SetDisplayMode],
                         @"IDirectDrawVMT::WaitForVerticalBlank": [NSValue valueWithPointer: &fe_IDirectDrawVMT_WaitForVerticalBlank],
                         @"IDirectDrawSurface7::QueryInterface":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_QueryInterface],
                         @"IDirectDrawSurface7::AddRef":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_AddRef],
                         @"IDirectDrawSurface7::Release":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_Release],
                         @"IDirectDrawSurface7::AddAttachedSurface":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_AddAttachedSurface],
                         @"IDirectDrawSurface7::AddOverlayDirtyRect":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_AddOverlayDirtyRect],
                         @"IDirectDrawSurface7::Blt":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_Blt],
                         @"IDirectDrawSurface7::BltBatch":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_BltBatch],
                         @"IDirectDrawSurface7::BltFast":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_BltFast],
                         @"IDirectDrawSurface7::DeleteAttachedSurface":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_DeleteAttachedSurface],
                         @"IDirectDrawSurface7::EnumAttachedSurfaces":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_EnumAttachedSurfaces],
                         @"IDirectDrawSurface7::EnumOverlayZOrders":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_EnumOverlayZOrders],
                         @"IDirectDrawSurface7::Flip":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_Flip],
                         @"IDirectDrawSurface7::GetAttachedSurface":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetAttachedSurface],
                         @"IDirectDrawSurface7::GetBltStatus":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetBltStatus],
                         @"IDirectDrawSurface7::GetCaps":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetCaps],
                         @"IDirectDrawSurface7::GetClipper":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetClipper],
                         @"IDirectDrawSurface7::GetColorKey":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetColorKey],
                         @"IDirectDrawSurface7::GetDC":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetDC],
                         @"IDirectDrawSurface7::GetFlipStatus":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetFlipStatus],
                         @"IDirectDrawSurface7::GetOverlayPosition":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetOverlayPosition],
                         @"IDirectDrawSurface7::GetPalette":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetPalette],
                         @"IDirectDrawSurface7::GetPixelFormat":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetPixelFormat],
                         @"IDirectDrawSurface7::GetSurfaceDesc":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetSurfaceDesc],
                         @"IDirectDrawSurface7::Initialize":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_Initialize],
                         @"IDirectDrawSurface7::IsLost":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_IsLost],
                         @"IDirectDrawSurface7::Lock":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_Lock],
                         @"IDirectDrawSurface7::ReleaseDC":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_ReleaseDC],
                         @"IDirectDrawSurface7::Restore":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_Restore],
                         @"IDirectDrawSurface7::SetClipper":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_SetClipper],
                         @"IDirectDrawSurface7::SetColorKey":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_SetColorKey],
                         @"IDirectDrawSurface7::SetOverlayPosition":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_SetOverlayPosition],
                         @"IDirectDrawSurface7::SetPalette":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_SetPalette],
                         @"IDirectDrawSurface7::Unlock":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_Unlock],
                         @"IDirectDrawSurface7::UpdateOverlay":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_UpdateOverlay],
                         @"IDirectDrawSurface7::UpdateOverlayDisplay":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_UpdateOverlayDisplay],
                         @"IDirectDrawSurface7::UpdateOverlayZOrder":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_UpdateOverlayZOrder],
                         @"IDirectDrawSurface7::GetDDInterface":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetDDInterface],
                         @"IDirectDrawSurface7::PageLock":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_PageLock],
                         @"IDirectDrawSurface7::PageUnlock":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_PageUnlock],
                         @"IDirectDrawSurface7::SetSurfaceDesc":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_SetSurfaceDesc],
                         @"IDirectDrawSurface7::SetPrivateData":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_SetPrivateData],
                         @"IDirectDrawSurface7::GetPrivateData":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetPrivateData],
                         @"IDirectDrawSurface7::FreePrivateData":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_FreePrivateData],
                         @"IDirectDrawSurface7::GetUniquenessValue":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetUniquenessValue],
                         @"IDirectDrawSurface7::ChangeUniquenessValue":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_ChangeUniquenessValue],
                         @"IDirectDrawSurface7::SetPriority":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_SetPriority],
                         @"IDirectDrawSurface7::GetPriority":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetPriority],
                         @"IDirectDrawSurface7::SetLOD":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_SetLOD],
                         @"IDirectDrawSurface7::GetLOD":[NSValue valueWithPointer:&fe_IDirectDrawSurface7_GetLOD],
                         @"IDirectDrawPalette::QueryInterface":[NSValue valueWithPointer:&fe_IDirectDrawPalette_QueryInterface],
                         @"IDirectDrawPalette::AddRef":[NSValue valueWithPointer:&fe_IDirectDrawPalette_AddRef],
                         @"IDirectDrawPalette::Release":[NSValue valueWithPointer:&fe_IDirectDrawPalette_Release],
                         @"IDirectDrawPalette::GetCaps":[NSValue valueWithPointer:&fe_IDirectDrawPalette_GetCaps],
                         @"IDirectDrawPalette::GetEntries":[NSValue valueWithPointer:&fe_IDirectDrawPalette_GetEntries],
                         @"IDirectDrawPalette::Initialize":[NSValue valueWithPointer:&fe_IDirectDrawPalette_Initialize],
                         @"IDirectDrawPalette::SetEntries":[NSValue valueWithPointer:&fe_IDirectDrawPalette_SetEntries]
                        };
    }
    return self;
}

- (void) addDelegate:(id<FEDDrawDLLDelegate>) delegate {
    [_delegates addObject: delegate];
}
- (void) removeDelegate:(id<FEDDrawDLLDelegate>) delegate {
    [_delegates removeObject: delegate];
}

- (void) enumerateDelegatesWithSelector:(SEL) selector block:(void(^)(id<FEDDrawDLLDelegate>))block {
    for(id<FEDDrawDLLDelegate> delegate in _delegates.allObjects.copy) {
        if([delegate respondsToSelector: selector]) {
            block(delegate);
        }
    }
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
