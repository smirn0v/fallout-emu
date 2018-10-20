//
//  FEDSoundDLL.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 30/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEDSoundDLL.h"
#import "FEProcess.h"
#import "FEThreadContext.h"
#import "FEImportsProxy.h"

static WAVEFORMATEX Waveformatex;

/*
 HRESULT WINAPI DirectSoundCreate(
 LPGUID lpGuid,
 LPDIRECTSOUND* ppDS,
 LPUNKNOWN  pUnkOuter
 );
 */
static uint8_t fe_DirectSoundCreate(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpGUID = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_ppDS = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_pUnkOuter = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
    if(process.logExternalCalls) {
        printf("lpGUID = 0x%x, lplpDD = 0x%x, pUnkOuter = 0x%x\n", arg_lpGUID, arg_ppDS, arg_pUnkOuter);
    }
    
    IDirectSound directSound;

    directSound.QueryInterface       = [process.importsProxy addressOfFunction: @"IDirectSound::QueryInterface" fromDLL: @"dsound.dll"];
    directSound.AddRef               = [process.importsProxy addressOfFunction: @"IDirectSound::AddRef" fromDLL:@"dsound.dll"];
    directSound.Release              = [process.importsProxy addressOfFunction: @"IDirectSound::Release" fromDLL:@"dsound.dll"];
    directSound.CreateSoundBuffer    = [process.importsProxy addressOfFunction: @"IDirectSound::CreateSoundBuffer" fromDLL:@"dsound.dll"];
    directSound.GetCaps              = [process.importsProxy addressOfFunction: @"IDirectSound::GetCaps" fromDLL:@"dsound.dll"];
    directSound.DuplicateSoundBuffer = [process.importsProxy addressOfFunction: @"IDirectSound::DuplicateSoundBuffer" fromDLL:@"dsound.dll"];
    directSound.SetCooperativeLevel  = [process.importsProxy addressOfFunction: @"IDirectSound::SetCooperativeLevel" fromDLL:@"dsound.dll"];
    directSound.Compact              = [process.importsProxy addressOfFunction: @"IDirectSound::Compact" fromDLL:@"dsound.dll"];
    directSound.GetSpeakerConfig     = [process.importsProxy addressOfFunction: @"IDirectSound::GetSpeakerConfig" fromDLL:@"dsound.dll"];
    directSound.SetSpeakerConfig     = [process.importsProxy addressOfFunction: @"IDirectSound::SetSpeakerConfig" fromDLL:@"dsound.dll"];
    directSound.Initialize           = [process.importsProxy addressOfFunction: @"IDirectSound::Initialize" fromDLL:@"dsound.dll"];
    
    uint32_t vdirectSound = fe_memoryMap_malloc(process.memory, sizeof(IDirectSound), kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write, "IDirectSound");
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, vdirectSound, &directSound, sizeof(IDirectSound));
    uint32_t vptrdirectSound = fe_memoryMap_malloc(process.memory, 4, kFEMemoryAccessMode_Write|kFEMemoryAccessMode_Read, "ptr to IDirectSound");
    
    fe_memoryMap_setValue32(process.memory, vptrdirectSound, vdirectSound);
    fe_memoryMap_setValue32(process.memory, arg_ppDS, vptrdirectSound);
    
    process.currentThread->eax = 0;
    
    return 12;
}

static uint8_t fe_IDirectSound_QueryInterface(FEProcess *process) {
    assert(0);
    return 0;
}

static uint8_t fe_IDirectSound_AddRef(FEProcess *process) {
    assert(0);
    return 0;
}

static uint8_t fe_IDirectSound_Release(FEProcess *process) {
    assert(0);
    return 0;
}


/*
 HRESULT CreateSoundBuffer(
    LPCDSBUFFERDESC lpcDSBufferDesc,
    LPLPDIRECTSOUNDBUFFER lplpDirectSoundBuffer,
    IUnknown FAR* pUnkOuter
 );
 */
static uint8_t fe_IDirectSound_CreateSoundBuffer(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpcDSBufferDesc = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lplpDirectSoundBuffer = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_pUnkOuter = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
#pragma unused(arg_this)
#pragma unused(arg_pUnkOuter)
    
    DSBUFFERDESC bufferDesc;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory, &bufferDesc, arg_lpcDSBufferDesc, sizeof(DSBUFFERDESC));
    
    IDirectSoundBuffer dsbuffer;
    dsbuffer.QueryInterface = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::QueryInterface" fromDLL:@"dsound.dll"];
    dsbuffer.AddRef = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::AddRef" fromDLL:@"dsound.dll"];
    dsbuffer.Release = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::Release" fromDLL:@"dsound.dll"];
    dsbuffer.GetCaps = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::GetCaps" fromDLL:@"dsound.dll"];
    dsbuffer.GetCurrentPosition = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::GetCurrentPosition" fromDLL:@"dsound.dll"];
    dsbuffer.GetFormat = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::GetFormat" fromDLL:@"dsound.dll"];
    dsbuffer.GetVolume = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::GetVolume" fromDLL:@"dsound.dll"];
    dsbuffer.GetPan = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::GetPan" fromDLL:@"dsound.dll"];
    dsbuffer.GetFrequency = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::GetFrequency" fromDLL:@"dsound.dll"];
    dsbuffer.GetStatus = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::GetStatus" fromDLL:@"dsound.dll"];
    dsbuffer.Initialize = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::Initialize" fromDLL:@"dsound.dll"];
    dsbuffer.Lock = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::Lock" fromDLL:@"dsound.dll"];
    dsbuffer.Play = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::Play" fromDLL:@"dsound.dll"];
    dsbuffer.SetCurrentPosition = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::SetCurrentPosition" fromDLL:@"dsound.dll"];
    dsbuffer.SetFormat = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::SetFormat" fromDLL:@"dsound.dll"];
    dsbuffer.SetVolume = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::SetVolume" fromDLL:@"dsound.dll"];
    dsbuffer.SetPan = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::SetPan" fromDLL:@"dsound.dll"];
    dsbuffer.SetFrequency = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::SetFrequency" fromDLL:@"dsound.dll"];
    dsbuffer.Stop = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::Stop" fromDLL:@"dsound.dll"];
    dsbuffer.Unlock = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::Unlock" fromDLL:@"dsound.dll"];
    dsbuffer.Restore = [process.importsProxy addressOfFunction: @"IDirectSoundBuffer::Restore" fromDLL:@"dsound.dll"];
    
    uint32_t vdsbuffer = fe_memoryMap_malloc(process.memory, sizeof(IDirectSoundBuffer), kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write, "IDirectSoundBuffer");
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, vdsbuffer, &dsbuffer, sizeof(IDirectSoundBuffer));
    
    uint32_t vptrdsbuffer = fe_memoryMap_malloc(process.memory, 4, kFEMemoryAccessMode_Write|kFEMemoryAccessMode_Read, "ptr to IDirectSoundBuffer");
    
    fe_memoryMap_setValue32(process.memory, vptrdsbuffer, vdsbuffer);
    fe_memoryMap_setValue32(process.memory, arg_lplpDirectSoundBuffer, vptrdsbuffer);
    
    process.currentThread->eax = 0;

    return 16;
}

/*
 HRESULT GetCaps(
    LPDSCAPS lpDSCaps
 );
 */
static uint8_t fe_IDirectSound_GetCaps(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpDSCaps = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
#pragma unused(arg_this)

    
    DSCAPS caps = {0};
    fe_memoryMap_memcpyToRealFromVirtual(process.memory, &caps, arg_lpDSCaps, sizeof(DSCAPS));
  
    caps.dwMinSecondarySampleRate = 96;
    caps.dwMaxSecondarySampleRate = 2907;
    caps.dwPrimaryBuffers = 8000;
    caps.dwMaxHwMixingAllBuffers = 48000;
    caps.dwMaxHwMixingStaticBuffers = 1;
    caps.dwMaxHwMixingStreamingBuffers = 1;
    caps.dwFreeHwMixingAllBuffers = 1;
    caps.dwFreeHwMixingStaticBuffers = 1;
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, arg_lpDSCaps, &caps, sizeof(DSCAPS));
    
    process.currentThread->eax = 0;
    
    return 8;
}

static uint8_t fe_IDirectSound_DuplicateSoundBuffer(FEProcess *process) {
    assert(0);
    return 0;
}

/*
 HRESULT SetCooperativeLevel(
 HWND hwnd,
 DWORD dwLevel
 );
 */
static uint8_t fe_IDirectSound_SetCooperativeLevel(FEProcess *process) {
    process.currentThread->eax = 0;
    return 12;
}

static uint8_t fe_IDirectSound_Compact(FEProcess *process) {
    assert(0);
    return 0;
}

static uint8_t fe_IDirectSound_GetSpeakerConfig(FEProcess *process) {
    assert(0);
    return 0;
}

static uint8_t fe_IDirectSound_SetSpeakerConfig(FEProcess *process) {
    assert(0);
    return 0;
}

static uint8_t fe_IDirectSound_Initialize(FEProcess *process) {
    assert(0);
    return 0;
}

static uint8_t fe_IDirectSoundBuffer_QueryInterface(FEProcess *process) { assert(0); return 0; }
static uint8_t fe_IDirectSoundBuffer_AddRef(FEProcess *process) { assert(0); return 0; }

static uint8_t fe_IDirectSoundBuffer_Release(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    fe_memoryMap_free(process.memory, arg_this);
    
    process.currentThread->eax = 0;
    return 4;
}


/*
 HRESULT GetCaps(
 LPDSBCAPS lpDSBufferCaps
 );
 */
static uint8_t fe_IDirectSoundBuffer_GetCaps(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpDSBufferCaps = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);

#pragma unused(arg_this)

    /*
     dwSize	20	unsigned long
     dwFlags	137	unsigned long
     dwBufferBytes	32768	unsigned long
     dwUnlockTransferRate	0	unsigned long
     dwPlayCpuOverhead	0	unsigned long
     */
    DSBCAPS caps = {0};
    caps.dwSize = 20;
    caps.dwFlags = 137;
    caps.dwBufferBytes = 32768;
    caps.dwUnlockTransferRate = 0;
    caps.dwPlayCpuOverhead = 0;
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, arg_lpDSBufferCaps, &caps, sizeof(DSBCAPS));
    
    process.currentThread->eax = 0;
    
    return 8;
}


/*
 HRESULT GetCurrentPosition(
 LPDWORD lpdwCurrentPlayCursor,
 LPDWORD lpdwCurrentWriteCursor
 );
 */
static uint8_t fe_IDirectSoundBuffer_GetCurrentPosition(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpdwCurrentPlayCursor = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lpdwCurrentWriteCursor = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
#pragma unused(arg_this)
    
    fe_memoryMap_setValue32(process.memory, arg_lpdwCurrentPlayCursor, 0);
    fe_memoryMap_setValue32(process.memory, arg_lpdwCurrentWriteCursor, 0);
    
    process.currentThread->eax = 0;
    
    return 12;
}

/*
 HRESULT GetFormat(
 LPWAVEFORMATEX lpwfxFormat,
 DWORD dwSizeAllocated,
 LPDWORD lpdwSizeWritten
 );
 */
static uint8_t fe_IDirectSoundBuffer_GetFormat(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpwfxFormat = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_dwSizeAllocated = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_lpdwSizeWritten = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);

#pragma unused(arg_this)

    if(arg_lpwfxFormat == 0) {
        fe_memoryMap_setValue32(process.memory, arg_lpdwSizeWritten, sizeof(Waveformatex));
    } else {
        fe_memoryMap_memcpyToVirtualFromReal(process.memory, arg_lpwfxFormat, &Waveformatex, arg_dwSizeAllocated);
    }
    
    process.currentThread->eax = 0;
    
    return 16;
}

static uint8_t fe_IDirectSoundBuffer_GetVolume(FEProcess *process) { assert(0); return 0; }
static uint8_t fe_IDirectSoundBuffer_GetPan(FEProcess *process) { assert(0); return 0; }
static uint8_t fe_IDirectSoundBuffer_GetFrequency(FEProcess *process) { assert(0); return 0; }

/*
 HRESULT GetStatus(
 LPDWORD lpdwStatus
 );
 */
static uint8_t fe_IDirectSoundBuffer_GetStatus(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpdwStatus = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
#pragma unused(arg_this)
    
    fe_memoryMap_setValue32(process.memory, arg_lpdwStatus, 0);
    
    process.currentThread->eax = 0;
    return 8;
}

static uint8_t fe_IDirectSoundBuffer_Initialize(FEProcess *process) { assert(0); return 0; }

/*
 HRESULT Lock(
 DWORD dwWriteCursor,
 DWORD dwWriteBytes,
 LPVOID lplpvAudioPtr1,
 LPDWORD lpdwAudioBytes1,
 LPVOID lplpvAudioPtr2,
 LPDWORD lpdwAudioBytes2,
 DWORD dwFlags
 );
 */
static uint8_t fe_IDirectSoundBuffer_Lock(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_dwWriteCursor = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_dwWriteBytes = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_lplpvAudioPtr1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    uint32_t arg_lpdwAudioBytes1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
    uint32_t arg_lplpvAudioPtr2 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+20);
    uint32_t arg_lpdwAudioBytes2 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+24);
    uint32_t arg_dwFlags = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+28);
 
#pragma unused(arg_this)
#pragma unused(arg_dwWriteCursor)
#pragma unused(arg_dwFlags)
    
    uint32_t audio_ptr = fe_memoryMap_malloc(process.memory, arg_dwWriteBytes, kFEMemoryAccessMode_Write, "IDirectSoundBuffer Lock");
    
    fe_memoryMap_setValue32(process.memory, arg_lplpvAudioPtr1, audio_ptr);
    fe_memoryMap_setValue32(process.memory, arg_lpdwAudioBytes1, arg_dwWriteBytes);
    
    if(arg_lplpvAudioPtr2) {
        fe_memoryMap_setValue32(process.memory, arg_lplpvAudioPtr2, 0);
        fe_memoryMap_setValue32(process.memory, arg_lpdwAudioBytes2, 0);
    }
    
    // printf("IDirectSoundBuffer Lock %d, flags 0x%X\n", arg_dwWriteBytes, arg_dwFlags);
    
    process.currentThread->eax = 0;
    return 32;
}

/*
 HRESULT Play(
 DWORD dwReserved1,
 DWORD dwReserved2,
 DWORD dwFlags
 );
 */
static uint8_t fe_IDirectSoundBuffer_Play(FEProcess *process) {
    process.currentThread->eax = 0;
    return 16;
}

/*
 HRESULT SetCurrentPosition(
 DWORD dwNewPosition
 );
 */
static uint8_t fe_IDirectSoundBuffer_SetCurrentPosition(FEProcess *process) {
    process.currentThread->eax = 0;
    return 8;
}

/*
 HRESULT SetFormat(
 LPCWAVEFORMATEX lpcfxFormat
 );
 */
static uint8_t fe_IDirectSoundBuffer_SetFormat(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpcfxFormat = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
#pragma unused(arg_this)

    
    fe_memoryMap_memcpyToRealFromVirtual(process.memory, &Waveformatex, arg_lpcfxFormat, sizeof(Waveformatex));
    
    
    process.currentThread->eax = 0;
    return 8;
}

/*
 HRESULT SetVolume(
 LONG lVolume
 );
 */
static uint8_t fe_IDirectSoundBuffer_SetVolume(FEProcess *process) {
    process.currentThread->eax = 0;
    return 8;
}

/*
 HRESULT SetPan(
 LONG lPan
 );
 */
static uint8_t fe_IDirectSoundBuffer_SetPan(FEProcess *process) {
    process.currentThread->eax = 0;
    return 8;
}

static uint8_t fe_IDirectSoundBuffer_SetFrequency(FEProcess *process) { assert(0); return 0; }

static uint8_t fe_IDirectSoundBuffer_Stop(FEProcess *process) {
    process.currentThread->eax = 0;
    return 4;
}

/*
 HRESULT Unlock(
 LPVOID lpvAudioPtr1,
 DWORD dwAudioBytes1,
 LPVOID lpvAudioPtr2,
 DWORD dwAudioBytes2
 );
 */
static uint8_t fe_IDirectSoundBuffer_Unlock(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_this = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpvAudioPtr1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_dwAudioBytes1 = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
#pragma unused(arg_this)
#pragma unused(arg_dwAudioBytes1)
    
    fe_memoryMap_free(process.memory, arg_lpvAudioPtr1);
    
    // printf("IDirectSoundBuffer Unlock %d\n", arg_dwAudioBytes1);
    
    process.currentThread->eax = 0;
    return 20;
}


static uint8_t fe_IDirectSoundBuffer_Restore(FEProcess *process) { assert(0); return 0; }

@implementation FEDSoundDLL {
    NSDictionary* _funcToImpMap;
}

- (instancetype)init
{
    self = [super init];
    if (self) {

        _funcToImpMap = @{
                          @"DirectSoundCreate": [NSValue valueWithPointer: &fe_DirectSoundCreate],
                          @"IDirectSound::QueryInterface": [NSValue valueWithPointer: &fe_IDirectSound_QueryInterface],
                          @"IDirectSound::AddRef": [NSValue valueWithPointer: &fe_IDirectSound_AddRef],
                          @"IDirectSound::Release": [NSValue valueWithPointer: &fe_IDirectSound_Release],
                          @"IDirectSound::CreateSoundBuffer": [NSValue valueWithPointer: &fe_IDirectSound_CreateSoundBuffer],
                          @"IDirectSound::GetCaps": [NSValue valueWithPointer: &fe_IDirectSound_GetCaps],
                          @"IDirectSound::DuplicateSoundBuffer": [NSValue valueWithPointer: &fe_IDirectSound_DuplicateSoundBuffer],
                          @"IDirectSound::SetCooperativeLevel": [NSValue valueWithPointer: &fe_IDirectSound_SetCooperativeLevel],
                          @"IDirectSound::Compact": [NSValue valueWithPointer: &fe_IDirectSound_Compact],
                          @"IDirectSound::GetSpeakerConfig": [NSValue valueWithPointer: &fe_IDirectSound_GetSpeakerConfig],
                          @"IDirectSound::SetSpeakerConfig": [NSValue valueWithPointer: &fe_IDirectSound_SetSpeakerConfig],
                          @"IDirectSound::Initialize": [NSValue valueWithPointer: &fe_IDirectSound_Initialize],
                          @"IDirectSoundBuffer::QueryInterface": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_QueryInterface],
                          @"IDirectSoundBuffer::AddRef": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_AddRef],
                          @"IDirectSoundBuffer::Release": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_Release],
                          @"IDirectSoundBuffer::GetCaps": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_GetCaps],
                          @"IDirectSoundBuffer::GetCurrentPosition": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_GetCurrentPosition],
                          @"IDirectSoundBuffer::GetFormat": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_GetFormat],
                          @"IDirectSoundBuffer::GetVolume": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_GetVolume],
                          @"IDirectSoundBuffer::GetPan": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_GetPan],
                          @"IDirectSoundBuffer::GetFrequency": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_GetFrequency],
                          @"IDirectSoundBuffer::GetStatus": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_GetStatus],
                          @"IDirectSoundBuffer::Initialize": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_Initialize],
                          @"IDirectSoundBuffer::Lock": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_Lock],
                          @"IDirectSoundBuffer::Play": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_Play],
                          @"IDirectSoundBuffer::SetCurrentPosition": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_SetCurrentPosition],
                          @"IDirectSoundBuffer::SetFormat": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_SetFormat],
                          @"IDirectSoundBuffer::SetVolume": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_SetVolume],
                          @"IDirectSoundBuffer::SetPan": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_SetPan],
                          @"IDirectSoundBuffer::SetFrequency": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_SetFrequency],
                          @"IDirectSoundBuffer::Stop": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_Stop],
                          @"IDirectSoundBuffer::Unlock": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_Unlock],
                          @"IDirectSoundBuffer::Restore": [NSValue valueWithPointer: &fe_IDirectSoundBuffer_Restore],
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