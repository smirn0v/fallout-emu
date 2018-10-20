//
//  main.m
//  fallout-emu
//
//  Created by Alexander Smirnov on 21/02/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//
#import <Foundation/Foundation.h>

#import "FEProcess.h"

#if 1

void test_executable(NSString *executable_file, NSString *reference_file) {
    @autoreleasepool {
        
        
        NSString *reference = [NSString stringWithContentsOfFile: reference_file
                                                        encoding: NSASCIIStringEncoding
                                                           error: nil];
        FEProcess *process = [[FEProcess alloc] initWithPathToExecutable: executable_file
                                                               diskCPath: @"/Users/smirnov/projects/fallout-emu/disk_c/"];
       
        //process.printStdOut = YES;
        //process.logInstructions = YES;
        [process run];
        
        
        if(![reference isEqualToString: process.stdoutBuffer]) {
            NSArray *resultLines = [process.stdoutBuffer componentsSeparatedByString: @"\n"];
            NSArray *referenceLines = [reference componentsSeparatedByString: @"\n"];
            
            for(int i = 0; i < MIN(resultLines.count, referenceLines.count); i++) {
                if(![referenceLines[i] isEqualToString: resultLines[i]]) {
                    fprintf(stderr,"reference line: %s\nresult line   : %s\n\n",
                            [referenceLines[i] cStringUsingEncoding: NSASCIIStringEncoding],
                            [resultLines[i] cStringUsingEncoding: NSASCIIStringEncoding]);
                }
            }
            
            fprintf(stderr,"Test failed for '%s'\n", [executable_file cStringUsingEncoding: NSASCIIStringEncoding]);
            exit(-1);
        }
    }
}
#endif

int main(int argc, const char * argv[]) {
    
    @autoreleasepool {
        
        for(int i = 0;i<10;i++) {

            test_executable(@"C:\\native-tests\\alu.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/alu-wine");
            test_executable(@"C:\\native-tests\\call-stack.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/call-stack-wine");
            test_executable(@"C:\\native-tests\\fib-15.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/fib-15-wine");
            test_executable(@"C:\\native-tests\\hello-world-10.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/hello-world-10-wine");
            test_executable(@"C:\\native-tests\\md5.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/md5-wine");
            test_executable(@"C:\\native-tests\\printf-hex-array.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/printf-hex-array-wine");
            test_executable(@"C:\\native-tests\\rotate.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/rotate-wine");
                test_executable(@"C:\\native-tests\\test-string.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/test-string-wine");
            test_executable(@"C:\\native-tests\\zero-and-sign-extend.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/zero-and-sign-extend-wine");
            test_executable(@"C:\\native-tests\\muldiv.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/muldiv-wine");
            test_executable(@"C:\\native-tests\\bcd.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/bcd-wine");
            test_executable(@"C:\\native-tests\\jcc.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/jcc-wine");
            test_executable(@"C:\\native-tests\\fpu-simple.exe", @"/Users/smirnov/projects/fallout-emu/disk_c/native-tests/fpu-simple-wine");
        }

//
//        FEProcess *process = [[FEProcess alloc] initWithPathToExecutable: [NSString stringWithCString: argv[1] encoding: NSASCIIStringEncoding]
//                                                               diskCPath: @"/Users/smirnov/projects/fallout-emu/disk_c/"];
//
//        //  process.logInstructionsAfter = 22328559;
//        // process.logInstructions = YES;
//        //  process.recordInstructionsUsageFrequency = YES;
//        // process.logExternalCalls = YES;
//        //process.printStdOut = YES;
//        [process run];
//
//        
        return 0;
    }
}
