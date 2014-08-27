//
//  MirrorDemoViewController.h
//  MirrorDemo
//
//  Created by David Fumberger on 26/08/2014.
//  Copyright (c) 2014 Collect3 Pty Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MirrorDemoViewController : UIViewController
@property (nonatomic, assign) CFTimeInterval startedTime;
@property (nonatomic, strong) NSTimer *timer;
@end
