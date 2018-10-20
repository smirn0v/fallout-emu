//
//  FEDInputDLL.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 30/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEDInputDLL.h"
#include "FEThreadContext.h"
#include "FEMemoryMap.h"
#import "FEStack.h"
#import "FEProcess.h"

/*
 HRESULT WINAPI DirectInputCreate(
 HINSTANCE hinst,
 DWORD dwVersion,
 LPDIRECTINPUT* lplpDirectInput,
 LPUNKNOWN punkOuter
 );
 */
static uint8_t fe_DirectInputCreateA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_hinst = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_dwVersion = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lplpDirectInput = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_punkOuter = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
#pragma unused(arg_hinst)
#pragma unused(arg_dwVersion)
#pragma unused(arg_punkOuter)
    
    FEImportsProxy *importsProxy = process.importsProxy;
    IDirectInputA directInputObj;
    directInputObj.QueryInterface = [importsProxy addressOfFunction: @"IDirectInputA::QueryInterface" fromDLL:@"dinput.dll"];
    directInputObj.AddRef = [importsProxy addressOfFunction:@"IDirectInputA::AddRef" fromDLL:@"dinput.dll"];
    directInputObj.Release = [importsProxy addressOfFunction:@"IDirectInputA::Release" fromDLL:@"dinput.dll"];
    directInputObj.CreateDevice = [importsProxy addressOfFunction:@"IDirectInputA::CreateDevice" fromDLL:@"dinput.dll"];
    directInputObj.EnumDevices = [importsProxy addressOfFunction:@"IDirectInputA::EnumDevices" fromDLL:@"dinput.dll"];
    directInputObj.GetDeviceStatus = [importsProxy addressOfFunction:@"IDirectInputA::GetDeviceStatus" fromDLL:@"dinput.dll"];
    directInputObj.RunControlPanel = [importsProxy addressOfFunction:@"IDirectInputA::RunControlPanel" fromDLL:@"dinput.dll"];
    directInputObj.Initialize = [importsProxy addressOfFunction:@"IDirectInputA::Initialize" fromDLL:@"dinput.dll"];
    
    uint32_t vdirectInputObj = fe_memoryMap_malloc(process.memory, sizeof(IDirectInputA), kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[ @"IDirectInputA" cStringUsingEncoding: NSASCIIStringEncoding]);
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,vdirectInputObj,&directInputObj,sizeof(IDirectInputA));
    
    uint32_t vptrdirectInputObj = fe_memoryMap_malloc(process.memory, 4, kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[@"ptr to IDirectInputA" cStringUsingEncoding: NSASCIIStringEncoding]);

    fe_memoryMap_setValue32(process.memory, vptrdirectInputObj, vdirectInputObj);
    fe_memoryMap_setValue32(process.memory, arg_lplpDirectInput, vptrdirectInputObj);
    
    process.currentThread->eax = 0;;
    
    return 16;
}

/*
 uint32_t QueryInterface;
 uint32_t AddRef;
 uint32_t Release;
 uint32_t CreateDevice;
 uint32_t EnumDevices;
 uint32_t GetDeviceStatus;
 uint32_t RunControlPanel;
 uint32_t Initialize;
 */

static uint8_t fe_IDirectInputA_QueryInterface(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectInputA_AddRef(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectInputA_Release(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT CreateDevice(
 REFGUID rguid,
 LPDIRECTINPUTDEVICE * lplpDirectInputDevice,
 LPUNKNOWN pUnkOuter
 )
 */
static uint8_t fe_IDirectInputA_CreateDevice(FEProcess *process) {

    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t arg_self = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_rguid = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_lplpDirectInputDevice = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_pUnkOuter = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
#pragma unused(arg_self)
#pragma unused(arg_pUnkOuter)
    
    NSString *deviceName = nil;
    uint32_t guid = fe_memoryMap_value32AtAddress(process.memory,arg_rguid);
    switch(guid) {
        case 0x6F1D2B60: {
            deviceName = @"mouse";
        }
            break;
        case 0x6F1D2B61: {
            deviceName = @"keyboard";
        }
            break;
        case 0x6F1D2B70: {
            deviceName = @"joystick";
        }
            break;
        case 0x6F1D2B80: {
            deviceName = @"mouseEm";
        }
            break;
        case 0x6F1D2B81: {
            deviceName = @"mouseEm2";
        }
            break;
        case 0x6F1D2B82: {
            deviceName = @"keyboardEm";
        }
            break;
        case 0x6F1D2B83: {
            deviceName = @"keyboardEm2";
        }
            break;
        default:
            deviceName = @"<unknown>";
    }
    
    if(process.logExternalCalls) {
        NSLog(@"%@",deviceName);
    }
    
    FEImportsProxy *importsProxy = process.importsProxy;
    IDirectInputDeviceA directInputDeviceObj;
    directInputDeviceObj.QueryInterface = [importsProxy addressOfFunction:@"IDirectInputDeviceA::QueryInterface" fromDLL:@"dinput.dll"];
    directInputDeviceObj.AddRef = [importsProxy addressOfFunction:@"IDirectInputDeviceA::AddRef" fromDLL:@"dinput.dll"];
    directInputDeviceObj.Release = [importsProxy addressOfFunction:@"IDirectInputDeviceA::Release" fromDLL:@"dinput.dll"];
    directInputDeviceObj.GetCapabilities = [importsProxy addressOfFunction:@"IDirectInputDeviceA::GetCapabilities" fromDLL:@"dinput.dll"];
    directInputDeviceObj.EnumObjects = [importsProxy addressOfFunction:@"IDirectInputDeviceA::EnumObjects" fromDLL:@"dinput.dll"];
    directInputDeviceObj.GetProperty = [importsProxy addressOfFunction:@"IDirectInputDeviceA::GetProperty" fromDLL:@"dinput.dll"];
    directInputDeviceObj.SetProperty = [importsProxy addressOfFunction:@"IDirectInputDeviceA::SetProperty" fromDLL:@"dinput.dll"];
    directInputDeviceObj.Acquire = [importsProxy addressOfFunction:@"IDirectInputDeviceA::Acquire" fromDLL:@"dinput.dll"];
    directInputDeviceObj.Unacquire = [importsProxy addressOfFunction:@"IDirectInputDeviceA::Unacquire" fromDLL:@"dinput.dll"];
    directInputDeviceObj.GetDeviceState = [importsProxy addressOfFunction:@"IDirectInputDeviceA::GetDeviceState" fromDLL:@"dinput.dll"];
    directInputDeviceObj.GetDeviceData = [importsProxy addressOfFunction:@"IDirectInputDeviceA::GetDeviceData" fromDLL:@"dinput.dll"];
    directInputDeviceObj.SetDataFormat = [importsProxy addressOfFunction:@"IDirectInputDeviceA::SetDataFormat" fromDLL:@"dinput.dll"];
    directInputDeviceObj.SetEventNotification = [importsProxy addressOfFunction:@"IDirectInputDeviceA::SetEventNotification" fromDLL:@"dinput.dll"];
    directInputDeviceObj.SetCooperativeLevel = [importsProxy addressOfFunction:@"IDirectInputDeviceA::SetCooperativeLevel" fromDLL:@"dinput.dll"];
    directInputDeviceObj.GetObjectInfo = [importsProxy addressOfFunction:@"IDirectInputDeviceA::GetObjectInfo" fromDLL:@"dinput.dll"];
    directInputDeviceObj.GetDeviceInfo = [importsProxy addressOfFunction:@"IDirectInputDeviceA::GetDeviceInfo" fromDLL:@"dinput.dll"];
    directInputDeviceObj.RunControlPanel = [importsProxy addressOfFunction:@"IDirectInputDeviceA::RunControlPanel" fromDLL:@"dinput.dll"];
    directInputDeviceObj.Initialize = [importsProxy addressOfFunction:@"IDirectInputDeviceA::Initialize" fromDLL:@"dinput.dll"];
    
    uint32_t vdirectInputDeviceObj = fe_memoryMap_malloc(process.memory, sizeof(IDirectInputDeviceA),kFEMemoryAccessMode_Write|kFEMemoryAccessMode_Read,[[NSString stringWithFormat:@"IDirectInputDeviceA %@",deviceName ] cStringUsingEncoding: NSASCIIStringEncoding]);
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,vdirectInputDeviceObj,&directInputDeviceObj,sizeof(IDirectInputDeviceA));
    
    uint32_t vptrdirectInputDeviceObj = fe_memoryMap_malloc(process.memory,4,kFEMemoryAccessMode_Read|kFEMemoryAccessMode_Write,[[NSString stringWithFormat:@"ptr to IDirectInputDeviceA %@",deviceName ] cStringUsingEncoding: NSASCIIStringEncoding]);
    fe_memoryMap_setValue32(process.memory,vptrdirectInputDeviceObj,vdirectInputDeviceObj);
    
    fe_memoryMap_setValue32(process.memory,arg_lplpDirectInputDevice,vptrdirectInputDeviceObj);
    
    process.currentThread->eax = 0;
    
    return 16;
}

static uint8_t fe_IDirectInputA_EnumDevices(FEProcess *process) {
    assert(false);
    return 0;
}


static uint8_t fe_IDirectInputA_GetDeviceStatus(FEProcess *process) {
    assert(0);
    return 0;
}

static uint8_t fe_IDirectInputA_RunControlPanel(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectInputA_Initialize(FEProcess *process) {
    assert(false);
    return 0;
}

static uint8_t fe_IDirectInputDeviceA_QueryInterface(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectInputDeviceA_AddRef(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectInputDeviceA_Release(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectInputDeviceA_GetCapabilities(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectInputDeviceA_EnumObjects(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectInputDeviceA_GetProperty(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT SetProperty(
 REFGUID rguidProp,
 LPCDIPROPHEADER pdiph
 )
 */
static uint8_t fe_IDirectInputDeviceA_SetProperty(FEProcess *process) {
    process.currentThread->eax = 0;
    return 12;
}

/*
 HRESULT Acquire()
 */
static uint8_t fe_IDirectInputDeviceA_Acquire(FEProcess *process) {
    process.currentThread->eax = 0;
    return 4;
}
static uint8_t fe_IDirectInputDeviceA_Unacquire(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT GetDeviceState(
 DWORD cbData,
 LPVOID lpvData
 )
 */
static uint8_t fe_IDirectInputDeviceA_GetDeviceState(FEProcess *process) {
    //0x8000000AL
    process.currentThread->eax = 0;
    return 12;
}

/*
 HRESULT GetDeviceData(
 DWORD cbObjectData,
 LPDIDEVICEOBJECTDATA rgdod,
 LPDWORD pdwInOut,
 DWORD dwFlags
 )
 */
static uint8_t fe_IDirectInputDeviceA_GetDeviceData(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_self = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_cbObjectData = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_rgdod = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_pdwInOut = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    uint32_t arg_dwFlags = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
    
#pragma unused(arg_self)
#pragma unused(arg_cbObjectData)
#pragma unused(arg_rgdod)
#pragma unused(arg_dwFlags)
    
    fe_memoryMap_setValue32(process.memory,arg_pdwInOut,0);
    process.currentThread->eax = 0;
    
    return 20;
}

/*
 HRESULT SetDataFormat(
 LPCDIDATAFORMAT lpdf
 )
 */

static uint8_t fe_IDirectInputDeviceA_SetDataFormat(FEProcess *process) {
    process.currentThread->eax = 0;
    return 8;
}
static uint8_t fe_IDirectInputDeviceA_SetEventNotification(FEProcess *process) {
    assert(false);
    return 0;
}

/*
 HRESULT SetCooperativeLevel(
 HWND hwnd,
 DWORD dwFlags
 )
 */
static uint8_t fe_IDirectInputDeviceA_SetCooperativeLevel(FEProcess *process) {
    process.currentThread->eax = 0;
    return 12;
}
static uint8_t fe_IDirectInputDeviceA_GetObjectInfo(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectInputDeviceA_GetDeviceInfo(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectInputDeviceA_RunControlPanel(FEProcess *process) {
    assert(false);
    return 0;
}
static uint8_t fe_IDirectInputDeviceA_Initialize(FEProcess *process) {
    assert(false);
    return 0;
}


@implementation FEDInputDLL {
    NSDictionary* _funcToImpMap;
}

- (instancetype)init
{
    self = [super init];
    if (self) {

   
        _funcToImpMap = @{
                          @"DirectInputCreateA": [NSValue valueWithPointer: &fe_DirectInputCreateA],
                          @"IDirectInputA::QueryInterface": [NSValue valueWithPointer: &fe_IDirectInputA_QueryInterface],
                          @"IDirectInputA::AddRef": [NSValue valueWithPointer: &fe_IDirectInputA_AddRef],
                          @"IDirectInputA::Release": [NSValue valueWithPointer: &fe_IDirectInputA_Release],
                          @"IDirectInputA::CreateDevice": [NSValue valueWithPointer: &fe_IDirectInputA_CreateDevice],
                          @"IDirectInputA::EnumDevices": [NSValue valueWithPointer: &fe_IDirectInputA_EnumDevices],
                          @"IDirectInputA::GetDeviceStatus": [NSValue valueWithPointer: &fe_IDirectInputA_GetDeviceStatus],
                          @"IDirectInputA::RunControlPanel": [NSValue valueWithPointer: &fe_IDirectInputA_RunControlPanel],
                          @"IDirectInputA::Initialize": [NSValue valueWithPointer: &fe_IDirectInputA_Initialize],
                          @"IDirectInputDeviceA::QueryInterface": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_QueryInterface],
                          @"IDirectInputDeviceA::AddRef": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_AddRef],
                          @"IDirectInputDeviceA::Release": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_Release],
                          @"IDirectInputDeviceA::GetCapabilities": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_GetCapabilities],
                          @"IDirectInputDeviceA::EnumObjects": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_EnumObjects],
                          @"IDirectInputDeviceA::GetProperty": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_GetProperty],
                          @"IDirectInputDeviceA::SetProperty": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_SetProperty],
                          @"IDirectInputDeviceA::Acquire": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_Acquire],
                          @"IDirectInputDeviceA::Unacquire": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_Unacquire],
                          @"IDirectInputDeviceA::GetDeviceState": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_GetDeviceState],
                          @"IDirectInputDeviceA::GetDeviceData": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_GetDeviceData],
                          @"IDirectInputDeviceA::SetDataFormat": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_SetDataFormat],
                          @"IDirectInputDeviceA::SetEventNotification": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_SetEventNotification],
                          @"IDirectInputDeviceA::SetCooperativeLevel": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_SetCooperativeLevel],
                          @"IDirectInputDeviceA::GetObjectInfo": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_GetObjectInfo],
                          @"IDirectInputDeviceA::GetDeviceInfo": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_GetDeviceInfo],
                          @"IDirectInputDeviceA::RunControlPanel": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_RunControlPanel],
                          @"IDirectInputDeviceA::Initialize": [NSValue valueWithPointer: &fe_IDirectInputDeviceA_Initialize]
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
