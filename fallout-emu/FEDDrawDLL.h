//
//  FEDDrawDLL.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 29/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FEImportsProxy.h"


typedef struct IDirectDraw	*LPDIRECTDRAW;
typedef struct IDirectDrawSurface7 *LPDIRECTDRAWSURFACE7;
typedef struct IDirectDrawPalette  *LPDIRECTDRAWPALETTE;
typedef struct DDSURFACEDESC *LPDDSURFACEDESC;


typedef struct tagPALETTEENTRY {
    uint8_t        peRed;
    uint8_t        peGreen;
    uint8_t        peBlue;
    uint8_t        peFlags;
} PALETTEENTRY, *PPALETTEENTRY, *LPPALETTEENTRY;

typedef struct _DDCOLORKEY
{
    uint32_t       dwColorSpaceLowValue;   // low boundary of color space that is to
                                           // be treated as Color Key, inclusive
    uint32_t       dwColorSpaceHighValue;  // high boundary of color space that is
                                           // to be treated as Color Key, inclusive
} DDCOLORKEY;

typedef struct _DDPIXELFORMAT
{
    uint32_t       dwSize;                 // size of structure
    uint32_t       dwFlags;                // pixel format flags
    uint32_t       dwFourCC;               // (FOURCC code)
    union
    {
        uint32_t   dwRGBBitCount;          // how many bits per pixel
        uint32_t   dwYUVBitCount;          // how many bits per pixel
        uint32_t   dwZBufferBitDepth;      // how many total bits/pixel in z buffer (including any stencil bits)
        uint32_t   dwAlphaBitDepth;        // how many bits for alpha channels
        uint32_t   dwLuminanceBitCount;    // how many bits per pixel
        uint32_t   dwBumpBitCount;         // how many bits per "buxel", total
    };
    union
    {
        uint32_t   dwRBitMask;             // mask for red bit
        uint32_t   dwYBitMask;             // mask for Y bits
        uint32_t   dwStencilBitDepth;      // how many stencil bits (note: dwZBufferBitDepth-dwStencilBitDepth is total Z-only bits)
        uint32_t   dwLuminanceBitMask;     // mask for luminance bits
        uint32_t   dwBumpDuBitMask;        // mask for bump map U delta bits
    };
    union
    {
        uint32_t   dwGBitMask;             // mask for green bits
        uint32_t   dwUBitMask;             // mask for U bits
        uint32_t   dwZBitMask;             // mask for Z bits
        uint32_t   dwBumpDvBitMask;        // mask for bump map V delta bits
    };
    union
    {
        uint32_t   dwBBitMask;             // mask for blue bits
        uint32_t   dwVBitMask;             // mask for V bits
        uint32_t   dwStencilBitMask;       // mask for stencil bits
        uint32_t   dwBumpLuminanceBitMask; // mask for luminance in bump map
    };
    union
    {
        uint32_t   dwRGBAlphaBitMask;      // mask for alpha channel
        uint32_t   dwYUVAlphaBitMask;      // mask for alpha channel
        uint32_t   dwLuminanceAlphaBitMask;// mask for alpha channel
        uint32_t   dwRGBZBitMask;          // mask for Z channel
        uint32_t   dwYUVZBitMask;          // mask for Z channel
    };
} DDPIXELFORMAT;

typedef struct _DDSCAPS
{
    uint32_t       dwCaps;         // capabilities of surface wanted
} DDSCAPS;


typedef struct IDirectDrawVMT
{
    uint32_t QueryInterface;
    uint32_t AddRef;
    uint32_t Release;
    
    uint32_t Compact;
    uint32_t CreateClipper;
    uint32_t CreatePalette;
    uint32_t CreateSurface;
    uint32_t DuplicateSurface;
    uint32_t EnumDisplayModes;
    uint32_t EnumSurfaces;
    uint32_t FlipToGDISurface;
    uint32_t GetCaps;
    uint32_t GetDisplayMode;
    uint32_t GetFourCCCodes;
    uint32_t GetGDISurface;
    uint32_t GetMonitorFrequency;
    uint32_t GetScanLine;
    uint32_t GetVerticalBlankStatus;
    uint32_t Initialize;
    uint32_t RestoreDisplayMode;
    uint32_t SetCooperativeLevel;
    uint32_t SetDisplayMode;
    uint32_t WaitForVerticalBlank;
    
} IDirectDrawVMT;

typedef struct IDirectDraw
{
    uint32_t VMT;
    
} IDirectDraw;

typedef struct _DDSURFACEDESC
{
    uint32_t               dwSize;                 // size of the DDSURFACEDESC structure
    uint32_t               dwFlags;                // determines what fields are valid
    uint32_t               dwHeight;               // height of surface to be created
    uint32_t               dwWidth;                // width of input surface
    union
    {
        uint32_t            lPitch;                 // distance to start of next line (return value only)
        uint32_t           dwLinearSize;           // Formless late-allocated optimized surface size
    };
    uint32_t               dwBackBufferCount;      // number of back buffers requested
    union
    {
        uint32_t           dwMipMapCount;          // number of mip-map levels requestde
                                                // dwZBufferBitDepth removed, use ddpfPixelFormat one instead
        uint32_t           dwRefreshRate;          // refresh rate (used when display mode is described)
        uint32_t           dwSrcVBHandle;          // The source used in VB::Optimize
    };
    uint32_t               dwAlphaBitDepth;        // depth of alpha buffer requested
    uint32_t               dwReserved;             // reserved
    uint32_t              lpSurface;              // pointer to the associated surface memory
    union
    {
        DDCOLORKEY      ddckCKDestOverlay;      // color key for destination overlay use
        uint32_t           dwEmptyFaceColor;       // Physical color for empty cubemap faces
    };
    DDCOLORKEY          ddckCKDestBlt;          // color key for destination blt use
    DDCOLORKEY          ddckCKSrcOverlay;       // color key for source overlay use
    DDCOLORKEY          ddckCKSrcBlt;           // color key for source blt use
    union
    {
        DDPIXELFORMAT   ddpfPixelFormat;        // pixel format description of the surface
        uint32_t           dwFVF;               // vertex format description of vertex buffers
    };
    DDSCAPS            ddsCaps;                // direct draw surface capabilities
} DDSURFACEDESC;

typedef struct _IDirectDrawSurface7
{
    /*** IUnknown methods ***/
    uint32_t QueryInterface;
    uint32_t AddRef;
    uint32_t Release;
    /*** IDirectDrawSurface methods ***/
    uint32_t AddAttachedSurface;
    uint32_t AddOverlayDirtyRect;
    uint32_t Blt;
    uint32_t BltBatch;
    uint32_t BltFast;
    uint32_t DeleteAttachedSurface;
    uint32_t EnumAttachedSurfaces;
    uint32_t EnumOverlayZOrders;
    uint32_t Flip;
    uint32_t GetAttachedSurface;
    uint32_t GetBltStatus;
    uint32_t GetCaps;
    uint32_t GetClipper;
    uint32_t GetColorKey;
    uint32_t GetDC;
    uint32_t GetFlipStatus;
    uint32_t GetOverlayPosition;
    uint32_t GetPalette;
    uint32_t GetPixelFormat;
    uint32_t GetSurfaceDesc;
    uint32_t Initialize;
    uint32_t IsLost;
    uint32_t Lock;
    uint32_t ReleaseDC;
    uint32_t Restore;
    uint32_t SetClipper;
    uint32_t SetColorKey;
    uint32_t SetOverlayPosition;
    uint32_t SetPalette;
    uint32_t Unlock;
    uint32_t UpdateOverlay;
    uint32_t UpdateOverlayDisplay;
    uint32_t UpdateOverlayZOrder;
    /*** Added in the v2 interface ***/
    uint32_t GetDDInterface;
    uint32_t PageLock;
    uint32_t PageUnlock;
    /*** Added in the v3 interface ***/
    uint32_t SetSurfaceDesc;
    /*** Added in the v4 interface ***/
    uint32_t SetPrivateData;
    uint32_t GetPrivateData;
    uint32_t FreePrivateData;
    uint32_t GetUniquenessValue;
    uint32_t ChangeUniquenessValue;
    /*** Moved Texture7 methods here ***/
    uint32_t SetPriority;
    uint32_t GetPriority;
    uint32_t SetLOD;
    uint32_t GetLOD;
} IDirectDrawSurface7;

typedef struct _IDirectDrawPalette {
    /*** IUnknown methods ***/
    uint32_t QueryInterface;
    uint32_t AddRef;
    uint32_t Release;
    /*** IDirectDrawPalette methods ***/
    uint32_t GetCaps;
    uint32_t GetEntries;
    uint32_t Initialize;
    uint32_t SetEntries;
}IDirectDrawPalette;

@class FEDDrawDLL;

@protocol FEDDrawDLLDelegate<NSObject>

- (void) feddrawdllNewData:(NSData*) data;

@end

@interface FEDDrawDLL : NSObject<FEDLLProxy>

- (void) addDelegate:(id<FEDDrawDLLDelegate>) delegate;
- (void) removeDelegate:(id<FEDDrawDLLDelegate>) delegate;

@end

