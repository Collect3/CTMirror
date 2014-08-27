//
//  MirrorDemoViewController.m
//  MirrorDemo
//
//  Created by David Fumberger on 26/08/2014.
//  Copyright (c) 2014 Collect3 Pty Ltd. All rights reserved.
//

#import "MirrorDemoViewController.h"
#include <CTMirror/CTMirror.h>

@interface MirrorTouchView : UIView

@end

@implementation MirrorTouchView
-(id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.45;
        self.layer.shadowRadius = 2.0f;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        [self.layer setShadowPath:[[UIBezierPath bezierPathWithOvalInRect:self.bounds] CGPath]]; // Optimises the shadow
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(c, self.tintColor.CGColor);
    CGContextFillEllipseInRect(c, rect);
}
@end

@interface MirrorDemoView  : UIView
@property (nonatomic, strong) NSMutableDictionary *touchViews;
@property (nonatomic, strong) UILabel *runningTimeLabel;
@property (nonatomic, strong) UIView *touchContentView;
@end

@implementation MirrorDemoView
- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.multipleTouchEnabled = YES;
        
        self.touchContentView = [[UIView alloc] initWithFrame: self.bounds];
        [self addSubview: self.touchContentView];
        
        self.runningTimeLabel = [[UILabel alloc] initWithFrame: self.bounds];
        self.runningTimeLabel.backgroundColor = [UIColor clearColor];
        self.runningTimeLabel.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
        self.runningTimeLabel.textAlignment = NSTextAlignmentCenter;
        self.runningTimeLabel.font =[UIFont fontWithName:@"AvenirNext-UltraLight" size:26];
        self.runningTimeLabel.text = @"00:00:00";
        [self addSubview: self.runningTimeLabel];
        
        self.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
        self.touchViews = [NSMutableDictionary dictionary];
    }
    return self;
}

- (UIColor*)colorForTouch:(NSInteger)t {
    float c = t / 10.0f;
    return [UIColor colorWithHue:c + 0.3  saturation:0.5 brightness:0.9 alpha:1.0];
}

- (void)showTouches:(NSSet*)set {
    for (UITouch *t in [set allObjects]) {
        NSInteger touchCount = [[self.touchContentView subviews] count];
        
        MirrorTouchView *touchView = [[MirrorTouchView alloc] initWithFrame: CGRectMake(0, 0, 32, 32)];
        [self.touchViews setObject: touchView  forKey: [self keyForTouch: t]];
        [self updateTouch: t];
        [self.touchContentView addSubview: touchView];
        touchView.backgroundColor = [UIColor clearColor];
        touchView.tintColor = [self colorForTouch: touchCount];
        touchView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        [UIView animateWithDuration:0.6 delay:0.0
             usingSpringWithDamping:0.5
              initialSpringVelocity:0.5
                            options:0
                         animations:^(void) {
                             touchView.transform = CGAffineTransformMakeScale(1.0, 1.0);
                         }
                         completion:^(BOOL finished) {
                             
                         }];
    }
}
- (NSString*)keyForTouch:(UITouch*)t {
    return  [NSString stringWithFormat:@"%p", t];
}

- (void)hideTouches:(NSSet*)set {
    for (UITouch *t in [set allObjects]) {
        NSString *key = [self keyForTouch: t];
        MirrorTouchView *touchView = [self.touchViews objectForKey: [NSString stringWithFormat:@"%p", t]];
        [UIView animateWithDuration:0.25 animations:^(void) {
//            touchView.alpha = 0.0f;
            touchView.transform = CGAffineTransformMakeScale(0.0, 0.0);
        }completion:^(BOOL finished) {
            [touchView removeFromSuperview];
            [self.touchViews removeObjectForKey: key];
        }];
    }
}

- (void)updateTouches:(NSSet*)set {
    for (UITouch *t in [set allObjects]) {
        [self updateTouch: t];
    }
}

- (void)updateTouch:(UITouch*)t {
    MirrorTouchView *touchView = [self.touchViews objectForKey:  [self keyForTouch: t]];
    touchView.center = [t locationInView: self.touchContentView];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    [self showTouches: touches];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    [self hideTouches: touches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent: event];
    [self hideTouches: touches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    [self updateTouches: touches];
}

- (void)layoutSubviews {
    self.touchContentView.frame = self.bounds;
    self.runningTimeLabel.frame = self.bounds;
    [super layoutSubviews];
}
@end

@interface MirrorDemoViewController () <CTMirrorPlayerDelegate, CTMirrorRecorderDelegate>

@end

@implementation MirrorDemoViewController

- (void)loadView {
    self.view = [[MirrorDemoView alloc] initWithFrame: CGRectZero];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.startedTime = CFAbsoluteTimeGetCurrent();
    [self startUpdateTimer];
    
#if TARGET_IPHONE_SIMULATOR
    [CTMirror sharedInstance].player.delegate = self;
#else
    [CTMirror sharedInstance].recorder.delegate = self;
#endif
    
}

- (MirrorDemoView*)mirrorDemoView {
    return (MirrorDemoView*)self.view;
}

- (void)startUpdateTimer {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                  target:self
                                                selector:@selector(timerTick)
                                                userInfo:nil repeats: YES];
}

- (void)timerTick {
    int duration = (int)(CFAbsoluteTimeGetCurrent() - self.startedTime);
    int seconds      = duration % 60;
    int minutes      = (duration / 60) % 60;
    int hours        = duration / 3600;
    NSString *time = [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];
    
    self.mirrorDemoView.runningTimeLabel.text = time;
}

#pragma mark -
#pragma mark CTMirror delegate methods
#pragma mark -
- (NSDictionary*)mirrorRecorderSaveState {
    return @{ @"startedTime" : [NSNumber numberWithDouble: self.startedTime] };
}

- (void)mirrorPlayerLoadState:(NSDictionary*)dict {
    self.startedTime = [[dict objectForKey: @"startedTime"] doubleValue];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
