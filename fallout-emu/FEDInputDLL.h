//
//  FEDInputDLL.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 30/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FEImportsProxy.h"

//DirectX Version 3.0

typedef struct IDirectInputA *LPDIRECTINPUT;
typedef struct IDirectInputDeviceA *LPDIRECTINPUTDEVICEA;

typedef struct IDirectInputA {
    /*** IUnknown methods ***/
    uint32_t QueryInterface;
    uint32_t AddRef;
    uint32_t Release;
    
    /*** IDirectInputA methods ***/
    uint32_t CreateDevice;
    uint32_t EnumDevices;
    uint32_t GetDeviceStatus;
    uint32_t RunControlPanel;
    uint32_t Initialize;
} IDirectInputA;

typedef struct IDirectInputDeviceA {
    /*** IUnknown methods ***/
    uint32_t QueryInterface;
    uint32_t AddRef;
    uint32_t Release;
    
    /*** IDirectInputDeviceA methods ***/
    uint32_t GetCapabilities;
    uint32_t EnumObjects;
    uint32_t GetProperty;
    uint32_t SetProperty;
    uint32_t Acquire;
    uint32_t Unacquire;
    uint32_t GetDeviceState;
    uint32_t GetDeviceData;
    uint32_t SetDataFormat;
    uint32_t SetEventNotification;
    uint32_t SetCooperativeLevel;
    uint32_t GetObjectInfo;
    uint32_t GetDeviceInfo;
    uint32_t RunControlPanel;
    uint32_t Initialize;
} IDirectInputDeviceA;


@interface FEDInputDLL : NSObject<FEDLLProxy>

@end
