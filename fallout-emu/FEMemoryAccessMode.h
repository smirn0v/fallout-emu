//
//  FEMemoryAccessMode.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 08/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

typedef enum FEMemoryAccessMode{
    kFEMemoryAccessMode_Read  = 1<<0,
    kFEMemoryAccessMode_Write = 1<<1,
    kFEMemoryAccessMode_Execute = 1<<2
} FEMemoryAccessMode;

//NSString* fe_memory_access_mode_description(FEMemoryAccessMode access);