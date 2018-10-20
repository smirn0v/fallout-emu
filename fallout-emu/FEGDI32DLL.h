//
//  FEGDI32DLL.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 29/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FEImportsProxy.h"

/* Stock GDI objects for GetStockObject() */

#define WHITE_BRUSH         0
#define LTGRAY_BRUSH        1
#define GRAY_BRUSH          2
#define DKGRAY_BRUSH        3
#define BLACK_BRUSH         4
#define NULL_BRUSH          5
#define HOLLOW_BRUSH        5
#define WHITE_PEN           6
#define BLACK_PEN           7
#define NULL_PEN            8
#define OEM_FIXED_FONT      10
#define ANSI_FIXED_FONT     11
#define ANSI_VAR_FONT       12
#define SYSTEM_FONT         13
#define DEVICE_DEFAULT_FONT 14
#define DEFAULT_PALETTE     15
#define SYSTEM_FIXED_FONT   16
#define DEFAULT_GUI_FONT    17
#define DC_BRUSH            18
#define DC_PEN              19

@interface FEGDI32DLL : NSObject<FEDLLProxy>

@end
