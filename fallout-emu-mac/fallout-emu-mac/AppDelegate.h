//
//  AppDelegate.h
//  fallout-emu-mac
//

//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SpriteKit/SpriteKit.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet SKView *skView;

@end
