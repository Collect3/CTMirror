//
//  CTMirrorPlayer.h
//  ToneBox
//
//  Created by David Fumberger on 13/08/2014.
//
//

#import <Foundation/Foundation.h>
#import "CTMirrorEvent.h"

@interface CTMirrorPlayer : NSObject
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) id delegate;
- (void)start ;
- (void)playbackCTMirrorEvent:(CTMirrorEventTouch*)event;
@end

@protocol CTMirrorPlayerDelegate <NSObject>
- (void)mirrorPlayerLoadState:(NSDictionary*)dict;
@end