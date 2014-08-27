//
//  CTMirrorEvent.m
//  ToneBox
//
//  Created by David Fumberger on 13/08/2014.
//
//

#import "CTMirrorEvent.h"

char *CTMirrorEventDataEOF = "DJF1234";

@implementation CTMirrorTouch
- (NSString*)description {
    return [NSString stringWithFormat:@"(CTMirrorEvent) [%@] Location [%f,%f] Phase [%i]",self.identifier, self.location.x, self.location.y, (int)self.phase];
}
- (void) encodeWithCoder: (NSCoder *)coder {
	[coder encodeCGPoint:self.location forKey:@"l"];
    [coder encodeInteger:self.phase    forKey:@"p"];
    [coder encodeInteger:self.taps     forKey:@"t"];
    [coder encodeObject:self.identifier forKey:@"id"];
    [coder encodeDouble:self.timestamp forKey:@"ts"];
}


- (id) initWithCoder:(NSCoder *)coder {
	if (self = [self init]) {
        self.location = [coder decodeCGPointForKey:@"l"];
        self.phase    = [coder decodeIntegerForKey:@"p"];
        self.taps     = [coder decodeIntegerForKey:@"t"];
        self.identifier = [coder decodeObjectForKey:@"id"];
        self.timestamp = [coder decodeDoubleForKey:@"ts"];
    }
    return self;
}

@end

@implementation CTMirrorEvent
@end

@implementation CTMirrorEventTouch


- (void) encodeWithCoder: (NSCoder *)coder {
    [coder encodeObject:self.touches forKey:@"touches"];
}

- (id) initWithCoder:(NSCoder *)coder {
	if (self = [self init]) {
        self.touches = [coder decodeObjectForKey:@"touches"];
    }
    return self;
}

@end

@implementation CTMirrorEventState

- (void) encodeWithCoder: (NSCoder *)coder {
	[coder encodeObject:self.dictionary forKey:@"dict"];
}


- (id) initWithCoder:(NSCoder *)coder {
	if (self = [self init]) {
        self.dictionary = [coder decodeObjectForKey:@"dict"];
    }
    return self;
}

@end
