//
//  CTMirror.m
//  CTMirror
//
//  Created by David Fumberger on 25/08/2014.
//  Copyright (c) 2014 Collect3 Pty Ltd. All rights reserved.
//

#import "CTMirror.h"

@implementation CTMirror
+ (CTMirror*)sharedInstance {
    DEFINE_SHARED_INSTANCE_USING_BLOCK(^{
        return [[self alloc] init];
    });
}

- (CTMirrorRecorder*)recorder {
    if (_recorder == nil) {
        _recorder = [[CTMirrorRecorder alloc] init];
    }
    return _recorder;
}

- (CTMirrorPlayer*)player {
    if (_player == nil) {
        _player = [[CTMirrorPlayer alloc] init];
    }
    return _player;
}

- (BOOL)recorderEnabled {
    if (self.recorder && self.recorder.started) {
        return YES;
    } else {
        return NO;
    }
}
@end
