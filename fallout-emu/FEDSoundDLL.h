//
//  FEDSoundDLL.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 30/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FEImportsProxy.h"

#include <inttypes.h>

typedef struct IDirectSound *LPDIRECTSOUND;
typedef struct IDirectSoundBuffer *LPDIRECTSOUNDBUFFER;

typedef struct {
    uint32_t dwSize;
    uint32_t dwFlags;
    uint32_t dwBufferBytes;
    uint32_t dwUnlockTransferRate;
    uint32_t dwPlayCpuOverhead;
} DSBCAPS, *LPDSBCAPS;

typedef const DSBCAPS *LPCDSBCAPS;

typedef struct _DSCAPS
{
    uint32_t           dwSize;
    uint32_t           dwFlags;
    uint32_t           dwMinSecondarySampleRate;
    uint32_t           dwMaxSecondarySampleRate;
    uint32_t           dwPrimaryBuffers;
    uint32_t           dwMaxHwMixingAllBuffers;
    uint32_t           dwMaxHwMixingStaticBuffers;
    uint32_t           dwMaxHwMixingStreamingBuffers;
    uint32_t           dwFreeHwMixingAllBuffers;
    uint32_t           dwFreeHwMixingStaticBuffers;
    uint32_t           dwFreeHwMixingStreamingBuffers;
    uint32_t           dwMaxHw3DAllBuffers;
    uint32_t           dwMaxHw3DStaticBuffers;
    uint32_t           dwMaxHw3DStreamingBuffers;
    uint32_t           dwFreeHw3DAllBuffers;
    uint32_t           dwFreeHw3DStaticBuffers;
    uint32_t           dwFreeHw3DStreamingBuffers;
    uint32_t           dwTotalHwMemBytes;
    uint32_t           dwFreeHwMemBytes;
    uint32_t           dwMaxContigFreeHwMemBytes;
    uint32_t           dwUnlockTransferRateHwBuffers;
    uint32_t           dwPlayCpuOverheadSwBuffers;
    uint32_t           dwReserved1;
    uint32_t           dwReserved2;
} DSCAPS, *LPDSCAPS;

typedef struct tWAVEFORMATEX
{
    uint16_t        wFormatTag;
    uint16_t        nChannels;
    uint32_t        nSamplesPerSec;
    uint32_t        nAvgBytesPerSec;
    uint16_t        nBlockAlign;
    uint16_t        wBitsPerSample;
    uint16_t        cbSize;
    
} WAVEFORMATEX, *LPWAVEFORMATEX;

typedef WAVEFORMATEX *LPWAVEFORMATEX;

typedef struct {
    uint32_t dwSize;
    uint32_t dwFlags;
    uint32_t dwBufferBytes;
    uint32_t dwReserved;
    uint32_t lpwfxFormat;
} DSBUFFERDESC, *LPDSBUFFERDESC;

typedef const DSBUFFERDESC *LPCDSBUFFERDESC;

typedef struct IDirectSound {
    // IUnknown methods
    uint32_t QueryInterface;
    uint32_t AddRef;
    uint32_t Release;
    
    // IDirectSound methods
    uint32_t CreateSoundBuffer;
    uint32_t GetCaps;
    uint32_t DuplicateSoundBuffer;
    uint32_t SetCooperativeLevel;
    uint32_t Compact;
    uint32_t GetSpeakerConfig;
    uint32_t SetSpeakerConfig;
    uint32_t Initialize;
} IDirectSound;

typedef struct IDirectSoundBuffer {
    // IUnknown methods
    uint32_t QueryInterface;
    uint32_t AddRef;
    uint32_t Release;
    
    // IDirectSoundBuffer methods
    uint32_t GetCaps;
    uint32_t GetCurrentPosition;
    uint32_t GetFormat;
    uint32_t GetVolume;
    uint32_t GetPan;
    uint32_t GetFrequency;
    uint32_t GetStatus;
    uint32_t Initialize;
    uint32_t Lock;
    uint32_t Play;
    uint32_t SetCurrentPosition;
    uint32_t SetFormat;
    uint32_t SetVolume;
    uint32_t SetPan;
    uint32_t SetFrequency;
    uint32_t Stop;
    uint32_t Unlock;
    uint32_t Restore;
} IDirectSoundBuffer;

@interface FEDSoundDLL : NSObject<FEDLLProxy>

@end
