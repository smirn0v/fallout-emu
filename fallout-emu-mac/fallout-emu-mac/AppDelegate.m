//
//  AppDelegate.m
//  fallout-emu-mac
//
//  Created by Alexander Smirnov on 08/11/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "AppDelegate.h"
#import "GameScene.h"
#import "FEProcess.h"
#import "FEDDrawDLL.h"



@implementation SKScene (Unarchive)

+ (instancetype)unarchiveFromFile:(NSString *)file {
    /* Retrieve scene file path from the application bundle */
    NSString *nodePath = [[NSBundle mainBundle] pathForResource:file ofType:@"sks"];
    /* Unarchive the file to an SKScene object */
    NSData *data = [NSData dataWithContentsOfFile:nodePath
                                          options:NSDataReadingMappedIfSafe
                                            error:nil];
    NSKeyedUnarchiver *arch = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    [arch setClass:self forClassName:@"SKScene"];
    SKScene *scene = [arch decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [arch finishDecoding];
        
    return scene;
}

@end

@interface AppDelegate()<FEDDrawDLLDelegate,GameSceneDelegate>
@end

@implementation AppDelegate {
    NSThread *_falloutThread;
    GameScene *scene;
    FEProcess *process;
}

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    scene = [GameScene unarchiveFromFile:@"GameScene"];
    [scene setGameSceneDelegate:  self];
    /* Set the scale mode to scale to fit the window */
    scene.scaleMode = SKSceneScaleModeAspectFit;

    [self.skView presentScene:scene];

    /* Sprite Kit applies additional optimizations to improve rendering performance */
    self.skView.ignoresSiblingOrder = YES;
    
    self.skView.showsFPS = YES;
    self.skView.showsNodeCount = YES;
    
    _falloutThread = [[NSThread alloc] initWithTarget:self selector:@selector(falloutThreadRun) object:nil];
     [_falloutThread start];
    
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Private

- (void) falloutThreadRun {
    
    process = [[FEProcess alloc] initWithPathToExecutable: @"C:\\GOG Games\\Fallout 2\\fallout2.exe"
                                                           diskCPath: @"/Users/smirnov/projects/fallout-emu/disk_c/"];
    
    FEDDrawDLL* ddraw  = (FEDDrawDLL*) [process.importsProxy proxyForDLLName: @"ddraw.dll"];
    NSCAssert(ddraw, @"ddraw needed");
    
    [ddraw addDelegate: self];

    //process.logExternalCalls = YES;

     [process run];
}

- (void) feddrawdllNewData:(NSData*) data {
    dispatch_sync(dispatch_get_main_queue(), ^{
        
        static char *frame;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            frame = malloc(640*480*4);
        });
        
        NSCAssert(data.length == 640*480*1,@"");
        
        for(int x = 0; x< 640-3; x++) {
            for(int y =0; y<480; y++) {
                *(frame+(y)*(640*4)+x*4) = *(((char*)data.bytes)+(y)*640 + x); //R
                *(frame+(y)*(640*4)+(x)*4+1) = 0; //G
                *(frame+(y)*(640*4)+(x)*4+2) = 0; //B
                *(frame+(y)*(640*4)+(x)*4+3) = 255; //A
            }
        }
        
        [scene updateWithData:[NSData dataWithBytesNoCopy:frame length:640*480*4 freeWhenDone:NO]];
        
        //        NSLog(@"New Frame");
    });
}

- (void) frameHandler {
    [scene setLabelText:[NSString stringWithFormat: @"%lld inst/millisecond, %lld M instr total", process.instrPerMillisecond, process.instrCounter/1000000]];
}

@end
