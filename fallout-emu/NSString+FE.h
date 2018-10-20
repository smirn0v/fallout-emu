//
//  NSString+FE.h
//  fallout-emu
//
//  Created by Alexander Smirnov on 08/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (FE)

+ (NSString*) fe_stringFromASCIIcstr:(char*) cstr;
- (NSInteger) fe_countOccurencesOfString:(NSString*)searchString;

- (NSString*) fe_win_stringByDeletingLastPathComponent;
- (NSString*) fe_win_stringByAppendingPathComponent:(NSString*) aString;

- (NSString*) fe_win_disk;

- (NSString*) fe_win_convertToRealPathWithDiskAtPath:(NSString*) diskPath currentPath:(NSString*) currentPath;

@end
