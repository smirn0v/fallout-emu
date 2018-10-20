//
//  NSString+FE.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 08/03/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "NSString+FE.h"

@implementation NSString (FE)

+ (NSString*) fe_stringFromASCIIcstr:(char*) cstr {
    return [NSString stringWithCString: cstr encoding: NSASCIIStringEncoding];
}

- (NSInteger) fe_countOccurencesOfString:(NSString*)searchString {
    NSInteger strCount = [self length] - [[self stringByReplacingOccurrencesOfString:searchString withString:@""] length];
    return strCount / [searchString length];
}

- (NSString*) fe_win_stringByDeletingLastPathComponent {
    NSRange backslash = [self rangeOfString: @"\\" options: NSBackwardsSearch];
    if(backslash.location!=NSNotFound) {
        return [self substringToIndex: NSMaxRange(backslash)];
    }
    return self;
}

- (NSString*) fe_win_stringByAppendingPathComponent:(NSString*) aString {
    NSString *ending = [self substringFromIndex: self.length-1];
    if([ending isEqualToString:@"\\"]) {
        return [self stringByAppendingString: aString];
    }
    return [self stringByAppendingFormat:@"\\%@", aString];
}

- (NSString*) fe_win_disk {
    // C:\
    //
    if(self.length >= 3) {
        if([[self substringWithRange:NSMakeRange(1, 2)] isEqualToString:@":\\"]) {
            NSString *disk = [self.uppercaseString substringToIndex: 1];
            NSRange diskRange = [disk rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
            if(diskRange.location == 0) {
                return [self.uppercaseString substringToIndex:1];
            }
        }
    }
    
    return nil;
}

- (NSString*) fe_win_convertToRealPathWithDiskAtPath:(NSString*) diskPath currentPath:(NSString*) currentPath {
    NSString *disk = [self fe_win_disk];
    
    if(disk) {
        NSArray *components = [[self substringFromIndex:3] componentsSeparatedByString:@"\\"];
        NSString *result = diskPath;
        for(NSString *pathComponent in components) {
            result = [result stringByAppendingPathComponent: pathComponent];
        }
        return result;
    }
    
    NSString *converted = [self stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    if(currentPath) {
        return [currentPath stringByAppendingPathComponent: converted];
    }
    return converted;
}


@end
