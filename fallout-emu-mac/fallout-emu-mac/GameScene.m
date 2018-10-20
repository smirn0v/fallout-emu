//
//  GameScene.m
//  fallout-emu-mac
//
//  Created by Alexander Smirnov on 08/11/15.
//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import "GameScene.h"
#include <CoreServices/CoreServices.h>
#include <mach/mach.h>
#include <mach/mach_time.h>


NSTimeInterval m_now() {
    uint64_t t = mach_absolute_time();
    Nanoseconds nano = AbsoluteToNanoseconds(*(AbsoluteTime *)&t);
    NSTimeInterval seconds = (double)*(uint64_t *)&nano / (double)NSEC_PER_SEC;
    return seconds;
}

@implementation GameScene {
    SKMutableTexture *_gameFrameTexture;
    SKLabelNode * _label;
    id<GameSceneDelegate> _delegate;
    NSTimeInterval _lastFrameTime;
    double _fps;
}

- (void) setGameSceneDelegate:(id<GameSceneDelegate>) delegate {
    _delegate = delegate;
}

-(void)didMoveToView:(SKView *)view {
    

    _gameFrameTexture = [[SKMutableTexture alloc] initWithSize:CGSizeMake(640,480) pixelFormat:'RGBA'];
    
    SKSpriteNode *spriteNode = [SKSpriteNode spriteNodeWithTexture:_gameFrameTexture];
    
    _label = [[SKLabelNode alloc] init];
    _label.position = CGPointMake(CGRectGetMidX(self.frame), 0);
    
    
    _label.text = @"sdfsdf";
    spriteNode.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame));
    spriteNode.yScale = -1.0f;
    
    [_gameFrameTexture modifyPixelDataWithBlock:^(void *pixelData, size_t lengthInBytes) {
        
//        NSData *data = [NSData dataWithContentsOfFile:@"/Users/smirnov/frames/1.original"];
//        char *frame = pixelData;
//
//        for(int x = 0; x< 640-3; x++) {
//            for(int y =0; y<480; y++) {
//                *(frame+(y)*(640*4)+x*4) = *(((char*)data.bytes)+(y)*640 + x); //R
//                *(frame+(y)*(640*4)+(x)*4+1) = 0; //G
//                *(frame+(y)*(640*4)+(x)*4+2) = 0; //B
//                *(frame+(y)*(640*4)+(x)*4+3) = 255; //A
//            }
//        }
        
         memset(pixelData, 255, lengthInBytes);
    }];

    [self addChild: spriteNode];
    [self addChild: _label];
}

-(void)mouseDown:(NSEvent *)theEvent {
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    [_delegate frameHandler];
}

- (void) setLabelText:(NSString*) text {
    _label.text = [NSString stringWithFormat:@"%@, fps = %f", text,_fps];
}

- (void) updateWithData:(NSData*) data {
    NSTimeInterval now = m_now();
    if(_lastFrameTime != 0) {
        _fps = 1.0/(now - _lastFrameTime);
    }
        _lastFrameTime = now;
    [_gameFrameTexture modifyPixelDataWithBlock:^(void *pixelData, size_t lengthInBytes) {
        memcpy(pixelData,data.bytes,MIN(lengthInBytes,data.length));
    }];
}

@end
