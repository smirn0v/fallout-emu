//
//  GameScene.h
//  fallout-emu-mac
//

//  Copyright (c) 2015 Alexander Smirnov. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@protocol GameSceneDelegate<NSObject>

- (void) frameHandler;

@end

@interface GameScene : SKScene

- (void) updateWithData:(NSData*) data;

- (void) setGameSceneDelegate:(id<GameSceneDelegate>) delegate;


- (void) setLabelText:(NSString*) text;

@end
