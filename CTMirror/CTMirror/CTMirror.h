//
//  CTMirror.h
//  CTMirror
//
//  Created by David Fumberger on 25/08/2014.
//  Copyright (c) 2014 Collect3 Pty Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CTMirrorRecorder.h"
#import "CTMirrorPlayer.h"

@interface CTMirror : NSObject
@property (nonatomic, strong) CTMirrorRecorder *recorder;
@property (nonatomic, strong) CTMirrorPlayer *player;
+ (CTMirror*)sharedInstance;
- (BOOL)recorderEnabled;
@end
