//
//  FEUser32DLL.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 29/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "FEUser32DLL.h"
#include "FEThreadContext.h"
#include "FEMemoryMap.h"
#include "FEMemoryMapBlock.h"
#import "FEStack.h"
#import "FEProcess.h"
#import "FEKernel32DLL.h"
#import "utils.h"

/*
 uint32_t handle_messages_and_return(uint32_t wndhandle, char *messages, uint32_t count, uint32_t(__stdcall *wndProc)(uint32_t wndhandle, uint32_t message, uint32_t wParam, uint32_t lParam), uint32_t result) {

     
     while(count != 0) {
         uint32_t message = *((uint32_t*)messages);
         uint32_t wParam = *((uint32_t*)messages+1);
         uint32_t lParam = *((uint32_t*)messages+2);
         
         wndProc(wndhandle, message, wParam, lParam);
         
         count--;
         messages+=12;
     }
     
     return result;
 }
 
 
 */
static const char handle_messages[] = {
    0x55, 0x89, 0xe5, 0x81, 0xec, 0x0c, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0x90, 0x8b, 0x45, 0x10,
    0x83, 0xf8, 0x00, 0x0f, 0x84, 0x49, 0x00, 0x00, 0x00, 0x8b, 0x45, 0x0c, 0x8b, 0x08, 0x89, 0x4d,
    0xfc, 0x8b, 0x45, 0x0c, 0x83, 0xc0, 0x04, 0x8b, 0x08, 0x89, 0x4d, 0xf8, 0x8b, 0x45, 0x0c, 0x83,
    0xc0, 0x08, 0x8b, 0x08, 0x89, 0x4d, 0xf4, 0x8b, 0x45, 0xf4, 0x50, 0x8b, 0x45, 0xf8, 0x50, 0x8b,
    0x45, 0xfc, 0x50, 0x8b, 0x45, 0x08, 0x50, 0x8b, 0x45, 0x14, 0xff, 0xd0, 0x8b, 0x45, 0x10, 0x89,
    0xc1, 0x83, 0xc0, 0xff, 0x89, 0x45, 0x10, 0x8b, 0x45, 0x0c, 0x83, 0xc0, 0x0c, 0x89, 0x45, 0x0c,
    0xeb, 0xab, 0x8b, 0x45, 0x18, 0xe9, 0x03, 0x00, 0x00, 0x00, 0x90, 0x90, 0x90, 0xc9, 0xc2, 0x14,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

@interface FEUser32DLL()
- (int32_t) showCursor:(BOOL) show;
@end

/*
 int WINAPI ShowCursor(
 _In_  BOOL bShow
 );
 */
static uint8_t fe_ShowCursor(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    uint32_t bShow = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    FEUser32DLL *user32 = [process.importsProxy proxyForDLLName: @"user32.dll"];
    int32_t showCounter = [user32 showCursor: bShow];
    
    process.currentThread->eax = showCounter;
    
    return 4;
}

/*
 HICON WINAPI LoadIcon(
 _In_opt_  HINSTANCE hInstance,
 _In_      LPCTSTR lpIconName
 );
 */
static uint8_t fe_LoadIconA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t hInstance = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t lpIconName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
    assert(lpIconName == 99);
    assert(hInstance == 0xaabbcc);
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    uint32_t handle =  [kernel32 createHandleType: kFEHandleType_IconHandle
                                             name: @"Icon"
                                          payload: @{
                                                     @"icon-name": @(lpIconName),
                                                     @"instance": @(hInstance)
                                                     }];
    
    process.currentThread->eax = handle;
    
    return 8;
}

/*
 ATOM WINAPI RegisterClass(
 _In_  const WNDCLASS *lpWndClass
 );
 */
static uint8_t fe_RegisterClassA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t wndclass = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    WNDCLASSA classcopy;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory,&classcopy,wndclass,sizeof(WNDCLASSA));
    PWNDCLASSA pwndclass = (PWNDCLASSA)&classcopy;
    
    assert(pwndclass->style == 3);
    assert(pwndclass->lpfnWndProc == 0x4de9fc);
    assert(pwndclass->hInstance == 0xaabbcc);
    assert(pwndclass->lpszClassName != 0);
    //assert(pwndclass->hIcon == 9001);
    //assert(pwndclass->hbrBackground == 5001);
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    uint32_t handle = [kernel32 createHandleType: kFEHandleType_ClassHandle
                                            name: @"ClassAtom"
                                         payload: @{
                                                    @"style": @(pwndclass->style),
                                                    @"wndproc": @(pwndclass->lpfnWndProc),
                                                    @"instance": @(pwndclass->hInstance),
                                                    @"icon": @(pwndclass->hIcon),
                                                    @"background": @(pwndclass->hbrBackground),
                                                    @"class-name": utils_memoryMap_createString(process.memory, pwndclass->lpszClassName)
                                                    }];
    
    process.currentThread->eax = handle;
    
    return 4;
}


/*
 int WINAPI GetSystemMetrics(
 _In_ int nIndex
 );

 */
static uint8_t fe_GetSystemMetrics(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_index = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);

    switch(arg_index) {
        case 0x1://cyscreen
            process.currentThread->eax = 760;
            break;
        case 0x0://cxscreen
            process.currentThread->eax = 1195;
            break;
        default:
            assert(false);
    }
    
    return 4;
}

/*
 HWND WINAPI CreateWindowEx(
 _In_     DWORD     dwExStyle,
 _In_opt_ LPCTSTR   lpClassName,
 _In_opt_ LPCTSTR   lpWindowName,
 _In_     DWORD     dwStyle,
 _In_     int       x,
 _In_     int       y,
 _In_     int       nWidth,
 _In_     int       nHeight,
 _In_opt_ HWND      hWndParent,
 _In_opt_ HMENU     hMenu,
 _In_opt_ HINSTANCE hInstance,
 _In_opt_ LPVOID    lpParam
 );
 */
static uint8_t fe_CreateWindowExA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_exStyle = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_className = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_windowName = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_style = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    uint32_t arg_x = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
    uint32_t arg_y = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+20);
    uint32_t arg_width = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+24);
    uint32_t arg_height = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+28);
    uint32_t arg_wndParent = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+32);
    uint32_t arg_menu = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+36);
    uint32_t arg_instance = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+40);
    uint32_t arg_param = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+44);
    
    FEUser32DLL *user32 = [process.importsProxy proxyForDLLName: @"user32.dll"];
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    
    NSString *className = utils_memoryMap_createString(process.memory, arg_className);
    NSString *windowName = utils_memoryMap_createString(process.memory, arg_windowName);
    
    uint32_t classHandle;
    BOOL classFound = [kernel32 handle: &classHandle withPredicate:^BOOL(NSDictionary *details) {
        if(((NSNumber*)details[@"type"]).unsignedIntegerValue == kFEHandleType_ClassHandle) {
            return [details[@"payload"][@"class-name"] isEqualToString: className];
        }
        return NO;
    }];
    
#pragma unused(classFound)
    
    assert(classFound);
    
    NSDictionary *classHandleDetails = [kernel32 handleDetails: classHandle];
    uint32_t wndProc = (uint32_t)[classHandleDetails[@"payload"][@"wndproc"] unsignedIntegerValue];
    uint32_t hbr = (uint32_t)[classHandleDetails[@"payload"][@"background"] unsignedIntegerValue];
    
    uint32_t windowHandle = [kernel32 createHandleType: kFEHandleType_WindowHandle
                                                  name: windowName
                                               payload: @{
                                                          @"class-handle": @(classHandle),
                                                          @"window-name": windowName,
                                                          @"instance": @(arg_instance)
                                                          }];
    /*
     The CreateWindowEx function sends WM_NCCREATE, WM_NCCALCSIZE, and WM_CREATE messages to the window being created.
     */
    // [user32 postMessage:0x0081 window:windowHandle wParam:0 lParam:0];
    
    //process.currentThread->eax = windowHandle;
    
    CREATESTRUCT createStruct = {
            .lpCreateParams = arg_param,
            .hInstance = arg_instance,
            .hMenu = arg_menu,
            .hwndParent = arg_wndParent,
            .cy =  arg_height,
            .cx =  arg_width,
            .y = arg_y,
            .x = arg_x,
            .style = arg_style,
            .lpszName = arg_windowName,
            .lpszClass = arg_className,
            .dwExStyle = arg_exStyle
    };
    
    RECT rectStruct = {
        .left = arg_x,
        .top = arg_y,
        .right = arg_width,
        .bottom = arg_height
    };
    
    WINDOWPOS posStruct = {
        .hwnd = arg_instance,
        .hwndInsertAfter = 0,
        .x = 0,
        .y = 0,
        .cx = 0,
        .cy = 0,
        .flags = 0x43 // SWP_SHOWWINDOW | SWP_NOSIZE | SWP_NOMOVE
    };
    NSString *createStructTag = [NSString stringWithFormat:@"create-struct{%@}", windowName];
    
    uint32_t vCreateStruct = fe_memoryMap_malloc(process.memory,
                                                 sizeof(CREATESTRUCT),
                                                 kFEMemoryAccessMode_Read| kFEMemoryAccessMode_Write,
                                                 [createStructTag cStringUsingEncoding: NSASCIIStringEncoding]);
    
   
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,vCreateStruct,&createStruct,sizeof(CREATESTRUCT));
    
    NSString *rectStructTag = [NSString stringWithFormat:@"rect-struct{%@}", windowName];
    uint32_t vRectStruct = fe_memoryMap_malloc(process.memory,
                                               sizeof(RECT),
                                               kFEMemoryAccessMode_Read| kFEMemoryAccessMode_Write,
                                               [rectStructTag cStringUsingEncoding:NSASCIIStringEncoding]);
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,vRectStruct,&rectStruct,sizeof(RECT));
    
    NSString *posTag = [NSString stringWithFormat:@"pos-struct{%@}", windowName];
    uint32_t vPos = fe_memoryMap_malloc(process.memory,
                                        sizeof(WINDOWPOS),
                                        kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write,
                                        [posTag cStringUsingEncoding: NSASCIIStringEncoding]);
    
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,vPos,&posStruct,sizeof(WINDOWPOS));
    
    /*
     0006F60C  F0 03 03 00 00 00 00 00  ð.....
     0006F614  00 00 00 00 00 00 00 00  ........
     0006F61C  9C 05 00 00 42 03 00 00  œ..B..
     0006F624  43 18 00 10 FC E9 4D 00  C.üéM.
     
     
     */
    posStruct.x = 0;
    posStruct.y = 0;
    posStruct.cx = 0x59c;
    posStruct.cy = 0x342;
    posStruct.flags = 0x10001843;
    
    NSString *posChangedTag = [NSString stringWithFormat:@"pos-changed-struct{%@}", windowName];
    uint32_t vPosChanged = fe_memoryMap_malloc(process.memory,
                                               sizeof(WINDOWPOS),
                                               kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Write,
                                               [posChangedTag cStringUsingEncoding: NSASCIIStringEncoding]);
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,vPos,&posStruct,sizeof(WINDOWPOS));

    

    uint32_t return_addr = fe_stack_pop32(process.currentThread->stack);
    
    // cleaning up arguments from CreateWindowEx
    uint32_t esp = process.currentThread->esp;
    esp += 48;
    process.currentThread->esp = esp;
    
    WNDMESSAGE initialMessages[] = {
        {.message = 0x81, .wParam = 0,   .lParam = vCreateStruct},  // WM_NCCREATE
        {.message = 0x83, .wParam = 0,   .lParam = vRectStruct},    // WM_NCCALCSIZE
        {.message = 0x01, .wParam = 0,   .lParam = vCreateStruct},  // WM_CREATE
        {.message = 0x05, .wParam = 0,   .lParam = 0x342059C},      // WM_SIZE
        {.message = 0x03, .wParam = 0,   .lParam = 0},              // WM_MOVE
        {.message = 0x18, .wParam = 1,   .lParam = 0},              // WM_SHOWWINDOW
        {.message = 0x46, .wParam = 0,   .lParam = vPos},           // WM_WINDOWPOSCHANGING
        {.message = 0x1c, .wParam = 1,   .lParam = 0},              // WM_ACTIVATEAPP
        {.message = 0x86, .wParam = 0,   .lParam = 0},              // WM_NCACTIVATE
        {.message = 0x06, .wParam = 1,   .lParam = 0},              // WM_ACTIVATE
        {.message = 0x07, .wParam = 0,   .lParam = 0},              // WM_SETFOCUS
        {.message = 0x85, .wParam = 1,   .lParam = 0},              // WM_NCPAINT
        {.message = 0x14, .wParam = hbr, .lParam = 0},              // WM_ERASEBKGND
        {.message = 0x47, .wParam = 0,   .lParam = vPosChanged},    // WM_WINDOWPOSCHANGED
      
        //0x0f; 00 00
        //0x85; xx 00
        /*
         0006F87C   CC040CBF
         0006F880   00000000
         */

         //0x46
         
         /*
         0006F648  F0 03 03 00 00 00 00 00  ð.....
         0006F650  00 00 00 00 00 00 00 00  ........
         0006F658  9C 05 00 00 42 03 00 00  œ..B..
         0006F660  14 00 00 00 FC E9 4D 00  ...üéM.
         0006F668  53 8E 42 7E FF 99 42 7E  SŽB~ÿ™B~
         0006F670  50 D4 78 73 F0 03 03 00  PÔxsð.
         

         */
        
    };
    
    uint32_t handler = [user32 handleMessages: initialMessages
                                        count: sizeof(initialMessages)/sizeof(WNDMESSAGE)
                                      wndProc: wndProc
                                    wndHandle: windowHandle
                                       result: windowHandle
                                      process: process];
    fe_stack_push32(process.currentThread->stack, return_addr);
    fe_stack_push32(process.currentThread->stack, handler);
    
    return 0;
}


/*
 LRESULT WINAPI DefWindowProc(
 _In_ HWND   hWnd,
 _In_ UINT   Msg,
 _In_ WPARAM wParam,
 _In_ LPARAM lParam
 );
 */
static uint8_t fe_DefWindowProcA(FEProcess *process) {
    
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_hWnd = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_Msg = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_wParam = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_lParam = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
    if(process.logExternalCalls) {
        printf("hWnd = 0x%x, Msg = 0x%x, wParam = 0x%x, lParam = 0x%x\n", arg_hWnd, arg_Msg, arg_wParam, arg_lParam);
    }
    
    process.currentThread->eax = 0;;
    
    
    
    
    return 16;
}

/*
BOOL UpdateWindow(
                  _In_  HWND hWnd
                  );
*/
static uint8_t fe_UpdateWindow(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_hWnd = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    
    FEUser32DLL *user32 = [process.importsProxy proxyForDLLName: @"user32.dll"];
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    
    NSDictionary *windowHandleDetails = [kernel32 handleDetails: arg_hWnd];
    assert(windowHandleDetails);
    
    uint32_t classHandle = (uint32_t)[windowHandleDetails[@"payload"][@"class-handle"] unsignedIntegerValue];
    
    NSDictionary *classHandleDetails = [kernel32 handleDetails: classHandle];
    assert(classHandleDetails);
    
    uint32_t wndProc = (uint32_t)[classHandleDetails[@"payload"][@"wndproc"] unsignedIntegerValue];
    uint32_t hbr = (uint32_t)[classHandleDetails[@"payload"][@"background"] unsignedIntegerValue];
    
    uint32_t return_addr = fe_stack_pop32(process.currentThread->stack);
    
    // cleaning up arguments from UpdateWindow
    uint32_t esp = process.currentThread->esp;
    esp += 4;
    process.currentThread->esp = esp;
    
    
    WNDMESSAGE initialMessages[] = {
        {.message = 0xf,  .wParam = 0, .lParam = 0}, //wm_paint
        {.message = 0x85, .wParam = arg_hWnd, .lParam  = 0}, //wm_ncpaint
        {.message = 0x14, .wParam = hbr, .lParam = 0} //WM_ERASEBKGND
    };

     uint32_t handler = [user32 handleMessages: initialMessages
                                         count: sizeof(initialMessages)/sizeof(WNDMESSAGE)
                                       wndProc: wndProc
                                     wndHandle: arg_hWnd
                                        result: 1
                                       process: process];
    
    fe_stack_push32(process.currentThread->stack, return_addr);
    fe_stack_push32(process.currentThread->stack, handler);


    
    return 0;
}

/*
 BOOL GetUpdateRect(
 _In_   HWND   hWnd,
 _Out_  LPRECT lpRect,
 _In_   BOOL   bErase
 );

 */
static uint8_t fe_GetUpdateRect(FEProcess* process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_hWnd = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpRect = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_bErase = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    
    if(process.logExternalCalls) {
        printf("hwnd = 0x%x, lpRect = 0x%x, bErase = 0x%x\n", arg_hWnd, arg_lpRect, arg_bErase);
    }
    
    /*
     0006FA70  00 00 00 00 00 00 00 00  ........
     0006FA78  9C 05 00 00 42 03 00 00  œ..B..
     */
    RECT rect = {
        .left = 0,
        .top  = 0,
        .right  = 0x59c,
        .bottom = 0x342
    };
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory,arg_lpRect,&rect,sizeof(RECT));
    
    process.currentThread->eax = 1;
    
    return 12;
}

/*
 HWND WINAPI SetFocus(
 _In_opt_ HWND hWnd
 );
 */
static uint8_t fe_SetFocus(FEProcess *process) {
    process.currentThread->eax = 0;;
    return 4;
}

/*
 SHORT WINAPI GetKeyState(
 _In_ int nVirtKey
 );

 */
static uint8_t fe_GetKeyState(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_nVirtKey = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    if(process.logExternalCalls) {
        NSLog(@"%x",arg_nVirtKey);
    }
    
    process.currentThread->eax = 0;

    return 4;
}

/*
 HHOOK WINAPI SetWindowsHookEx(
 _In_ int       idHook,
 _In_ HOOKPROC  lpfn,
 _In_ HINSTANCE hMod,
 _In_ DWORD     dwThreadId
 );

 */
static uint8_t fe_SetWindowsHookExA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_idHook = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_lpfn = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_hMod = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_dwThreadId = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    
    if(process.logExternalCalls) {
        printf("idHook = 0x%x, lpfn = 0x%x, hMod = 0x%x, dwThreadId = 0x%x\n",arg_idHook,arg_lpfn,arg_hMod,arg_dwThreadId);
    }
    
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    uint32_t hook = [kernel32 createHandleType: kFEHandleType_Hook
                                          name: [NSString stringWithFormat:@"hook 0x%x",arg_idHook]
                                       payload: nil];
    
    process.currentThread->eax = hook;
    return 16;
}


/*
 BOOL WINAPI PeekMessage(
 _Out_    LPMSG lpMsg,
 _In_opt_ HWND  hWnd,
 _In_     UINT  wMsgFilterMin,
 _In_     UINT  wMsgFilterMax,
 _In_     UINT  wRemoveMsg
 );

 */
static uint8_t fe_PeekMessageA(FEProcess *process) {
    process.currentThread->eax = 0;
    return 20;
#if 0
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpMsg = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_hWnd = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    uint32_t arg_wMsgFilterMin = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+8);
    uint32_t arg_wMsgFilterMax = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+12);
    uint32_t arg_wRemoveMsg = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+16);
    
#pragma unused(arg_lpMsg)
#pragma unused(arg_hWnd)
#pragma unused(arg_wMsgFilterMin)
#pragma unused(arg_wMsgFilterMax)
#pragma unused(arg_wRemoveMsg)
    
    MSG message;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory, &message, arg_lpMsg, sizeof(MSG));
    
    message.message = 0xf;
    message.hwnd = 978679; //XXX
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, arg_lpMsg, &message, sizeof(MSG));
    
    process.currentThread->eax = 1;
    
    return 20;
#endif
}

/*
 BOOL WINAPI GetMessage(
 _Out_    LPMSG lpMsg,
 _In_opt_ HWND  hWnd,
 _In_     UINT  wMsgFilterMin,
 _In_     UINT  wMsgFilterMax
 );
 */
static uint8_t fe_GetMessageA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpMsg = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    uint32_t arg_hWnd = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs+4);
    
#pragma unused(arg_hWnd)
    
    MSG message;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory, &message, arg_lpMsg, sizeof(MSG));
    
    message.message = 0xf;
    message.hwnd = 978679; // XXX
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, arg_lpMsg, &message, sizeof(MSG));
    
    process.currentThread->eax = 1;

    
    return 16;
}

/*
 BOOL WINAPI TranslateMessage(
 _In_ const MSG *lpMsg
 );
 */
static uint8_t fe_TranslateMessage(FEProcess *process) {
    
    process.currentThread->eax = 1;
    
    return 4;
}

/*
 LRESULT WINAPI DispatchMessage(
 _In_ const MSG *lpmsg
 );
 */
static uint8_t fe_DispatchMessageA(FEProcess *process) {
    uint32_t ptrToArgs = process.currentThread->esp+4;
    
    uint32_t arg_lpmsg = fe_memoryMap_value32AtAddress(process.memory, ptrToArgs);
    
    MSG msg;
    fe_memoryMap_memcpyToRealFromVirtual(process.memory, &msg, arg_lpmsg, sizeof(MSG));
    assert(msg.message == 0xf);
    FEUser32DLL *user32 = [process.importsProxy proxyForDLLName: @"user32.dll"];
    FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
    
    NSDictionary *windowHandleDetails = [kernel32 handleDetails: msg.hwnd];
    assert(windowHandleDetails);
    
    uint32_t classHandle = (uint32_t)[windowHandleDetails[@"payload"][@"class-handle"] unsignedIntegerValue];
    
    NSDictionary *classHandleDetails = [kernel32 handleDetails: classHandle];
    assert(classHandleDetails);
    
    uint32_t wndProc = (uint32_t)[classHandleDetails[@"payload"][@"wndproc"] unsignedIntegerValue];
    
    uint32_t return_addr = fe_stack_pop32(process.currentThread->stack);
    
    // cleaning up arguments from CreateWindowEx
    uint32_t esp = process.currentThread->esp;
    esp += 4;
    process.currentThread->esp = esp;
    
    
    WNDMESSAGE initialMessages[] = {
        {.message = msg.message,  .wParam = msg.wParam, .lParam = msg.lParam},
    };
    
    uint32_t handler = [user32 handleMessages: initialMessages
                                        count: sizeof(initialMessages)/sizeof(WNDMESSAGE)
                                      wndProc: wndProc
                                    wndHandle: msg.hwnd
                                       result: 0
                                      process: process];
    
    fe_stack_push32(process.currentThread->stack, return_addr);
    fe_stack_push32(process.currentThread->stack, handler);
    
    return 0;
}

@implementation FEUser32DLL {
    NSMutableDictionary *_messages;
    NSDictionary *_funcToImpMap;
    int32_t _showCursorCounter;
}

- (instancetype)init
{
    self = [super init];
    if (self) {

        _messages = @{}.mutableCopy;
        _funcToImpMap = @{
                         @"ShowCursor": [NSValue valueWithPointer: &fe_ShowCursor],
                         @"LoadIconA": [NSValue valueWithPointer: &fe_LoadIconA],
                         @"RegisterClassA": [NSValue valueWithPointer: &fe_RegisterClassA],
                         @"GetSystemMetrics": [NSValue valueWithPointer: &fe_GetSystemMetrics],
                         @"CreateWindowExA": [NSValue valueWithPointer: &fe_CreateWindowExA],
                         @"DefWindowProcA": [NSValue valueWithPointer: &fe_DefWindowProcA],
                         @"UpdateWindow": [NSValue valueWithPointer: &fe_UpdateWindow],
                         @"GetUpdateRect": [NSValue valueWithPointer: &fe_GetUpdateRect],
                         @"SetFocus": [NSValue valueWithPointer: &fe_SetFocus],
                         @"GetKeyState": [NSValue valueWithPointer: &fe_GetKeyState],
                         @"SetWindowsHookExA": [NSValue valueWithPointer: &fe_SetWindowsHookExA],
                         @"PeekMessageA": [NSValue valueWithPointer: &fe_PeekMessageA],
                         @"GetMessageA": [NSValue valueWithPointer: &fe_GetMessageA],
                         @"TranslateMessage": [NSValue valueWithPointer: &fe_TranslateMessage],
                         @"DispatchMessageA": [NSValue valueWithPointer: &fe_DispatchMessageA]
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
        FEKernel32DLL *kernel32 = [process.importsProxy proxyForDLLName: @"kernel32.dll"];
        kernel32.lastError = 0;
        
        FEFunctionProxyIMP imp = funcPtr.pointerValue;
        return imp(process);
    }
    assert(false);
    return 0;
}

- (void) postMessage:(WNDMESSAGE) message forWindow:(uint32_t) window {
    NSMutableArray *messages = _messages[@(window)];
    if(!messages) {
        messages = @[].mutableCopy;
        _messages[@(window)] = messages;
    }
    
    [messages addObject: @{
                           @"message": @(message.message),
                           @"wParam": @(message.wParam),
                           @"lParam": @(message.lParam)
                           }];
}


- (uint32_t) handleMessages:(WNDMESSAGE*) messages
                      count:(uint32_t) count
                    wndProc:(uint32_t) wndProc
                  wndHandle:(uint32_t) wndHandle
                     result:(uint32_t) result
                    process:(FEProcess*) process {
    
    uint32_t handler;
    FEMemoryMapBlock *memoryBlock = fe_memoryMap_blockWithTag(process.memory, "FEMessagesHandler");
    
    if(!memoryBlock) {
        handler = fe_memoryMap_malloc(process.memory,
                                      sizeof(handle_messages),
                                      kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Execute | kFEMemoryAccessMode_Write,
                                      "FEMessagesHandler");
        
        fe_memoryMap_memcpyToVirtualFromReal(process.memory, handler, (void*)handle_messages, sizeof(handle_messages));
        
        memoryBlock = fe_memoryMap_blockWithTag(process.memory, "FEMessagesHandler");
        
        fe_memoryMap_setAccessModeAtAddress(process.memory, kFEMemoryAccessMode_Read | kFEMemoryAccessMode_Execute, memoryBlock->virtualAddress, memoryBlock->size);
        
    } else {
        handler = memoryBlock->virtualAddress;
    }
    
    //XXX need to free

    uint32_t vmessages = fe_memoryMap_malloc(process.memory,
                                             sizeof(WNDMESSAGE)*count,
                                             kFEMemoryAccessMode_Read| kFEMemoryAccessMode_Write,
                                             "Windows Messages");
    
    fe_memoryMap_memcpyToVirtualFromReal(process.memory, vmessages, messages, sizeof(WNDMESSAGE)*count);

    
    // void handle_messages_and_return(uint32_t wndhandle,
    //                                 char *messages,
    //                                 uint32_t count,
    //                                 uint32_t(*wndProc)(uint32_t wndHandle, uint32_t message, uint32_t wParam, uint32_t lParam),
    //                                 uint32_t result)
    
    fe_stack_push32(process.currentThread->stack, result);
    fe_stack_push32(process.currentThread->stack, wndProc);
    fe_stack_push32(process.currentThread->stack, count);
    fe_stack_push32(process.currentThread->stack, vmessages);
    fe_stack_push32(process.currentThread->stack, wndHandle);

    return handler;
}

#pragma mark - Private

- (int32_t) showCursor:(BOOL) show {
    if(show) {
        _showCursorCounter++;
    } else {
        _showCursorCounter--;
    }
    return _showCursorCounter;
}

@end
