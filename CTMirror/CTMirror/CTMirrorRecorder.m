//
//  InterationSimulatorRecorder.m
//  ToneBox
//
//  Created by David Fumberger on 13/08/2014.
//
//

#import "CTMirrorRecorder.h"
#import "GCDAsyncSocket.h"
#import "CTMirrorEvent.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

@protocol CTMirrorGestureDelegate
- (void)interactionGestureTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)interactionGestureTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)interactionGestureTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)interactionGestureTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface CTMirrorGesture : UIGestureRecognizer
@property (nonatomic, assign) id <CTMirrorGestureDelegate>interactionDelegate;
@end

@implementation CTMirrorGesture
- (id)init {
    if (self = [super init]) {
        self.cancelsTouchesInView = NO;
        self.delaysTouchesEnded = NO;
        self.delaysTouchesBegan = NO;
    }
    return self;
}
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.interactionDelegate interactionGestureTouchesBegan:touches withEvent:event];
    [super touchesBegan:touches withEvent:event];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.interactionDelegate interactionGestureTouchesMoved:touches withEvent: event];
    [super touchesMoved:touches withEvent:event];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    NSInteger allTouchesCount = [[[event allTouches] allObjects] count];
    [self.interactionDelegate interactionGestureTouchesEnded:touches withEvent:event];
    [super touchesEnded:touches withEvent:event];
    
    if (allTouchesCount == 1) {
        self.state = UIGestureRecognizerStateFailed;
    }

}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    NSInteger allTouchesCount = [[[event allTouches] allObjects] count];
    [self.interactionDelegate interactionGestureTouchesCancelled:touches withEvent:event];
    [super touchesCancelled:touches withEvent:event];
    if (allTouchesCount == 1) {
        self.state = UIGestureRecognizerStateFailed;
    }
}
@end

@interface CTMirrorRecorder() <GCDAsyncSocketDelegate, CTMirrorGestureDelegate, NSNetServiceBrowserDelegate, UIGestureRecognizerDelegate, CTMirrorGestureDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic, strong) GCDAsyncSocket *socket;
@property (nonatomic, strong) dispatch_queue_t socketQueue;
@property (nonatomic, strong) NSTimer *connectionTimer;
@property (nonatomic, strong) NSNetServiceBrowser *netBrowser;
@property (nonatomic, strong) NSMutableArray *foundPlayers;
@property (nonatomic, strong) CTMirrorGesture *mirrorGestureRecogniser;
@property (nonatomic, strong) UIView *chromaOverlayView;
@end

@implementation CTMirrorRecorder
+ (CTMirrorRecorder*)sharedInstance {
    DEFINE_SHARED_INSTANCE_USING_BLOCK(^{
        return [[self alloc] init];
    });
}

- (id)init {
    if (self = [super init]) {
        self.foundPlayers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)start {
    if (self.started) {
        return;
    }

    self.mirrorGestureRecogniser = [[CTMirrorGesture alloc] init];
    self.mirrorGestureRecogniser.delegate = self;
    self.mirrorGestureRecogniser.interactionDelegate = self;
    [self.window addGestureRecognizer: self.mirrorGestureRecogniser];
    self.window.multipleTouchEnabled = YES;
    
    self.socketQueue = dispatch_queue_create("CTMirrorRecorderSocketQueue", NULL);
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketQueue];
    
    // Try and find recorders on the network
    self.netBrowser = [[NSNetServiceBrowser alloc] init];
    self.netBrowser.delegate = self;
    [self.netBrowser searchForServicesOfType:@"_mirror._tcp." inDomain:@"local."];
    
    // User a timer to poll whether we've found any
    self.connectionTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                            target:self
                                                          selector:@selector(checkConnect)
                                                          userInfo:nil repeats:YES];
    self.started = YES;
}

- (void)setConnected:(BOOL)connected {
    _connected = connected;
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self checkOverlayState];
    });

}

- (void)checkOverlayState {
    if (self.chromaKeyOnConnect) {
        if (self.connected && !self.chromaOverlayView) {
            self.chromaOverlayView = [[UIView alloc] initWithFrame: self.window.bounds];
            self.chromaOverlayView.backgroundColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.75];
            self.chromaOverlayView.userInteractionEnabled = NO;
            [self.window addSubview: self.chromaOverlayView];
        } else if (!self.connected && self.chromaOverlayView) {
            [self.chromaOverlayView removeFromSuperview];
        }
    }
}

- (UIWindow*)window {
    return [[UIApplication sharedApplication].windows objectAtIndex:0];
}

- (void)stop {
    [self.connectionTimer invalidate];
    [self.socket disconnect];
    self.socketQueue = nil;
    self.started = NO;
    
    [self.window removeGestureRecognizer: self.mirrorGestureRecogniser];
}

- (void)checkConnect {
    if (self.connected) {
        return;
    }
    
    NSError *error = nil;
    NSLog(@"CTMirrorRecorder: checkConnect");
    
    if (self.playerHost) {
        
        [self.socket connectToHost:self.playerHost onPort:1982 error:&error];
        
    } else {

        // Find first service that is resolved
        NSNetService *service = nil;
        for (service in self.foundPlayers) {
            if ([service.addresses count] > 0) {
                NSLog(@" |_ Found!");
                break;
            } else {
                service = nil;
            }
        }
        
        if (service == nil) {
            NSLog(@" |_ No services");
            return;
        } else {
            NSLog(@" |_ Service %@", service);
        }
        
        [self.socket connectToAddress:service.addresses[0] error:&error];
        
    }
    
    if (error) {
        NSLog(@"CTMirrorRecorder: Error %@", error);
    }
}

- (void)recordCTMirrorEvent:(CTMirrorEventTouch*)event {
    NSMutableData *data = [[NSKeyedArchiver archivedDataWithRootObject: event] mutableCopy];
    [data appendBytes:CTMirrorEventDataEOF length:strlen(CTMirrorEventDataEOF)];
    [self.socket writeData:data withTimeout:1.0 tag:1];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {

}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    self.connected = YES;
    NSLog(@"CTMirrorRecorder: didConnectToHost: %@", host);
    [self syncState];
}

- (void)recordTouch:(NSSet*)touches withEvent:(UIEvent*)event {
    [self recordTouch:touches withEvent:event endPhase:NO];
}

- (void)recordTouch:(NSSet*)touches withEvent:(UIEvent*)event endPhase:(BOOL)endPhase {
    NSMutableSet *sets = [NSMutableSet set];
    for (UITouch *touch in [touches allObjects]) {
        CTMirrorTouch *interactionTouch = [[CTMirrorTouch alloc] init];
        interactionTouch.location   = [touch locationInView: [self recorderView]];
        interactionTouch.phase      = (endPhase) ? UITouchPhaseEnded : [touch phase];
        interactionTouch.taps       = [touch tapCount];
        interactionTouch.identifier = [NSString stringWithFormat:@"%p", touch];
        interactionTouch.timestamp  = CFAbsoluteTimeGetCurrent();
        [sets addObject: interactionTouch];
        //NSLog(@"CTMirrorRecorder: %@", interactionTouch);
    }
    CTMirrorEventTouch *interactionEvent = [[CTMirrorEventTouch alloc] init];
    interactionEvent.touches = sets;
    [self recordCTMirrorEvent: interactionEvent];
}

- (UIView*)recorderView {
    return [self.window.subviews objectAtIndex:0];
}

- (void)interactionGestureTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self recordTouch: touches withEvent: event];
}
- (void)interactionGestureTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [self recordTouch: touches withEvent: event];
}
- (void)interactionGestureTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [self recordTouch: touches withEvent: event];
    NSLog(@"cancelled");
}
- (void)interactionGestureTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [self recordTouch: touches withEvent: event];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return YES;
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    self.connected = NO;
}
- (void)syncState {
    if (![self.delegate respondsToSelector:@selector(mirrorRecorderSaveState)]) {
        return;
    }
    NSDictionary *dict = [self.delegate mirrorRecorderSaveState];
    CTMirrorEventState *state = [[CTMirrorEventState alloc] init];
    state.dictionary = dict;

    NSMutableData *data = [[NSKeyedArchiver archivedDataWithRootObject: state] mutableCopy];
    [data appendBytes:CTMirrorEventDataEOF length:strlen(CTMirrorEventDataEOF)];
    [self.socket writeData:data withTimeout:1.0 tag:1];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    NSLog(@"CTMirrorRecorder: Found Player %@", netService);
    [self.foundPlayers addObject: netService];
    [netService resolveWithTimeout:1.0];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    NSLog(@"CTMirrorRecorder: Removed Player %@", netService);
    [self.foundPlayers removeObject: netService];
}


@end
