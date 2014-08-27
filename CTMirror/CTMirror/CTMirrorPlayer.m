//
//  CTMirrorPlayer.m
//  ToneBox
//
//  Created by David Fumberger on 13/08/2014.
//
//

#import "CTMirrorPlayer.h"
#import "CTMirrorEvent.h"
#import "GCDAsyncSocket.h"
#import "UIView-KIFAdditions.h"
#import "UITouch-KIFAdditions.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <objc/runtime.h>
#import <objc/message.h>
static const void *KIFRunLoopModesKey = &KIFRunLoopModesKey;

#define UIApplicationCurrentRunMode ([[UIApplication sharedApplication] currentRunLoopMode])

@implementation UIApplication (KIFAdditions)
- (NSMutableArray *)KIF_runLoopModes;
{
    NSMutableArray *modes = objc_getAssociatedObject(self, KIFRunLoopModesKey);
    if (!modes) {
        modes = [NSMutableArray arrayWithObject:(id)kCFRunLoopDefaultMode];
        objc_setAssociatedObject(self, KIFRunLoopModesKey, modes, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return modes;
}

- (CFStringRef)currentRunLoopMode;
{
    return (__bridge CFStringRef)[self KIF_runLoopModes].lastObject;
}
@end

@interface CTMirrorPlayer() <GCDAsyncSocketDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) GCDAsyncSocket *currentSocket;
@property (nonatomic, strong) dispatch_queue_t socketQueue;
@property (nonatomic, strong) NSMutableDictionary *touchCache;
@property (nonatomic, strong) NSNetService *netService;
@property (nonatomic, assign) NSTimeInterval lastCTMirrorTimestamp;
@end

@implementation CTMirrorPlayer
- (id)init {
    if (self = [super init]) {
        self.touchCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)start {
    if (self.netService == nil) {
        self.netService = [[NSNetService alloc] initWithDomain:@"local." type:@"_mirror._tcp." name:@"CT Mirror Recorder" port:1982];
        [self.netService publish];
    }
    
    if (self.socketQueue == nil) {
        self.socketQueue = dispatch_queue_create("CTMirrorPlayerSocketQueue", NULL);
    }
    
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
    
    NSError *error = nil;
    [self.socket acceptOnPort:1982 error:&error];
    if (error) {
        NSLog(@"Error %@", error);
    }
    self.started = YES;
}

- (void)stop {
    [self.socket disconnect];
    self.socket = nil;
    
    self.started = NO;
}

- (UIWindow*)window {
    return [[UIApplication sharedApplication].windows objectAtIndex:0];
}

- (UIView*)playbackOnView {
    return [self.window.subviews objectAtIndex:0];
//    UIWindow *w = [[UIApplication sharedApplication].windows objectAtIndex:0];
//    return [w.subviews lastObject];
}

- (UITouch*)cachedUITouchForEventTouch:(CTMirrorTouch*)eventTouch {
    return self.touchCache[eventTouch.identifier];
}

- (void)cacheUITouch:(UITouch*)t forEventTouch:(CTMirrorTouch*)eventTouch {
    self.touchCache[eventTouch.identifier] = t;
}

- (void)removeEventTouchFromCache:(CTMirrorTouch*)eventTouch {
    [self.touchCache removeObjectForKey: eventTouch.identifier];
}

- (void)playbackCTMirrorEvent:(CTMirrorEventTouch*)interactionEvent {
    //NSLog(@"Playback CTMirror Event: %@", interactionEvent);
    
    UIWindow *w = [[UIApplication sharedApplication].windows objectAtIndex:0];
    
    UIView *touchView = [self playbackOnView];
    for (CTMirrorTouch *interactionTouch in interactionEvent.touches) {
        UITouch *touch = [self cachedUITouchForEventTouch: interactionTouch];
        //NSLog(@"%@", interactionTouch);
        if (touch == nil && interactionTouch.phase != UITouchPhaseBegan) {
            NSLog(@"CTMirrorPlayer: Warning, couldnt find touch for id [%@] phase %i", interactionTouch.identifier, (int)interactionTouch.phase);
            return;
        }
        if (interactionTouch.phase == UITouchPhaseBegan) {
            touch = [[UITouch alloc] initAtPoint:interactionTouch.location inView:touchView];
            [self cacheUITouch: touch forEventTouch: interactionTouch];
        } else{

        }
        
        // Moved / Stationary / Ended / Cancelled
        CGPoint lastLocation = [touch locationInView: w];
        NSTimeInterval lastTime = self.lastCTMirrorTimestamp;// interactionTouch.timestamp;

        [touch setTapCountInternal: interactionTouch.taps];
        [touch setPhaseAndUpdateTimestamp:interactionTouch.phase];
        
        if (interactionTouch.phase != UITouchPhaseBegan) {
            [touch setLocationInWindow: [touchView convertPoint:interactionTouch.location toView:w]];
        }

        UIEvent *event  = [touchView eventWithTouch:touch];
        
        
        CGPoint newLocation = [touch locationInView: w];
        
        // Take the time from the original touch so the deltas are correct
        // TODO: Put the timestamp on the UITouch so it can be tracked more correctly
        NSTimeInterval newTime        = interactionTouch.timestamp;
        self.lastCTMirrorTimestamp = interactionTouch.timestamp;

        // Hack to ensure scrolling works correctly
        if (interactionTouch.phase == UITouchPhaseMoved) {
            for (UIPanGestureRecognizer *gesture in touch.gestureRecognizers) {
                if ([gesture isKindOfClass: [UIPanGestureRecognizer class]]) {
                    UIPanGestureVelocitySample *sample = [gesture _previousVelocitySample];
                    sample.start = CGPointMake(lastLocation.x, lastLocation.y);
                    sample.end = CGPointMake(newLocation.x, newLocation.y);
                    sample.dt = newTime - lastTime;
                }
            }
        }
        
        [[UIApplication sharedApplication] sendEvent:event];

        // Ended / Cancelled
        if (interactionTouch.phase == UITouchPhaseEnded || interactionTouch.phase == UITouchPhaseCancelled) {
            [self removeEventTouchFromCache: interactionTouch];
        }
        
    }
    return;
}

- (void)restoreStateCTMirrorEvent:(CTMirrorEventState*)state {
    if (![self.delegate respondsToSelector:@selector(mirrorPlayerLoadState:)]) {
        return;
    }
    [self.delegate mirrorPlayerLoadState: state.dictionary];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if ([sock isEqual:self.currentSocket]) {
        unsigned long finalLength = [data length] - strlen(CTMirrorEventDataEOF);
        NSMutableData *finalData = [data mutableCopy];
        [finalData setLength:finalLength];
        
        CTMirrorEventTouch *event = [NSKeyedUnarchiver unarchiveObjectWithData:finalData];

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([event isKindOfClass:[CTMirrorEventTouch class]]) {
                [self playbackCTMirrorEvent: event];
            } else if ([event isKindOfClass: [CTMirrorEventState class]]) {
                [self restoreStateCTMirrorEvent: (CTMirrorEventState*)event];
            }

        });
        [self readNext];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    self.currentSocket = newSocket;
    NSLog(@"CTMirrorPlayer: didAcceptNewSocket: %@", sock);
    [self readNext];
}

- (void)readNext {
    NSData *eof = [NSData dataWithBytes:CTMirrorEventDataEOF length:strlen(CTMirrorEventDataEOF)];
    [self.currentSocket readDataToData:eof withTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"CTMirrorPlayer: socketDidDisconnect");
    if ([sock isEqual: self.currentSocket]) {
        self.currentSocket = nil;
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    NSLog(@"CTMirrorPlayer: didConnectToHost: %@", host);
    [self.currentSocket readDataWithTimeout:-1 tag:0];
}


@end
