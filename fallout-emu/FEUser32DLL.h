//
//  FEUser32DLL.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 29/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FEImportsProxy.h"


typedef struct tagPOINT {
    int32_t x;
    int32_t y;
} POINT, *PPOINT;

typedef struct tagMSG {
    uint32_t   hwnd;
    uint32_t   message;
    uint32_t wParam;
    uint32_t lParam;
    uint32_t  time;
    POINT  pt;
} MSG, *PMSG, *LPMSG;

typedef struct tagWNDCLASSA
{

    uint32_t      style;
    uint32_t   lpfnWndProc;
    uint32_t       cbClsExtra;
    uint32_t       cbWndExtra;
    uint32_t hInstance;
    uint32_t     hIcon;
    
    uint32_t   hCursor;
    uint32_t    hbrBackground;
    
    uint32_t      lpszMenuName;
    uint32_t      lpszClassName;
    
} WNDCLASSA, *PWNDCLASSA, *LPWNDCLASSA;

typedef struct tagCREATESTRUCT {
    uint32_t    lpCreateParams;
    uint32_t    hInstance;
    uint32_t    hMenu;
    uint32_t    hwndParent;
    uint32_t    cy;
    uint32_t    cx;
    uint32_t    y;
    uint32_t    x;
    uint32_t    style;
    uint32_t    lpszName;
    uint32_t    lpszClass;
    uint32_t    dwExStyle;
} CREATESTRUCT, *LPCREATESTRUCT;

typedef struct _RECT {
    uint32_t left;
    uint32_t top;
    uint32_t right;
    uint32_t bottom;
} RECT, *PRECT;


typedef struct WNDMESSAGE {
    uint32_t message;
    uint32_t wParam;
    uint32_t lParam;
} WNDMESSAGE;

typedef struct tagWINDOWPOS {
    uint32_t hwnd;
    uint32_t hwndInsertAfter;
    uint32_t  x;
    uint32_t  y;
    uint32_t  cx;
    uint32_t  cy;
    uint32_t flags;
} WINDOWPOS, *LPWINDOWPOS, *PWINDOWPOS;

/*
 UINT       style;
 WNDPROC    lpfnWndProc;
 int        cbClsExtra;
 int        cbWndExtra;
 HINSTANCE  hInstance;
 HICON      hIcon;
 HCURSOR    hCursor;
 HBRUSH     hbrBackground;
 LPCTSTR    lpszMenuName;
 LPCTSTR    lpszClassName;
 */

@interface FEUser32DLL : NSObject<FEDLLProxy>

- (void) postMessage:(WNDMESSAGE) message forWindow:(uint32_t) window;
- (uint32_t) handleMessages:(WNDMESSAGE*) messages
                      count:(uint32_t) count
                    wndProc:(uint32_t) wndProc
                  wndHandle:(uint32_t) wndHandle
                     result:(uint32_t) result
                    process:(FEProcess*) process;

@end
