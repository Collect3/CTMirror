//
//  CTMirrorEvent.h
//  CTMirror
//
//  Created by David Fumberger on 13/08/2014.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
extern char *CTMirrorEventDataEOF;

@interface CTMirrorTouch : NSObject
@property (nonatomic, assign) CGPoint location;
@property (nonatomic, assign) UITouchPhase phase;
@property (nonatomic, assign) NSInteger taps;
@property (nonatomic, assign) CFAbsoluteTime timestamp;
@property (nonatomic, strong) NSString *identifier;
@end


@interface CTMirrorEvent : NSObject
@end

@interface CTMirrorEventTouch : CTMirrorEvent
@property (nonatomic, strong) NSSet *touches;
@end

@interface CTMirrorEventState : CTMirrorEvent
@property (nonatomic, strong) NSDictionary *dictionary;
@end