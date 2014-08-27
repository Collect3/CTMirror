//
//  InterationSimulatorRecorder.h
//  ToneBox
//
//  Created by David Fumberger on 13/08/2014.
//
//

#import <Foundation/Foundation.h>

@interface CTMirrorRecorder : NSObject

/**
 * Set the delegate to handle state syncing
 */
@property (nonatomic, assign) id delegate;

/**
 * Setting this value bypassing Bonjour discovery and connects directly to the IP set.
 * Leave blank to auto discover.
 */
@property (nonatomic, strong) NSString *playerHost;

/**
 * Setting to true will automatically green screen the UIWindow when the recorder connects
 * to a player
 */
@property (nonatomic, assign) BOOL chromaKeyOnConnect;


/**
 * Calling start will cause the recorder to listen for
 * events and start seeking out a player on the network
 */
- (void)start;

/**
 * Calling stop will remove the listener from the UIWindow
 * and disconnect from the player
 */
- (void)stop;

/**
 * Started
 */
@property (nonatomic, assign) BOOL started;

/**
 * Connected to a host
 */
@property (nonatomic, assign) BOOL connected;

@end

@protocol CTMirrorRecorderDelegate <NSObject>
- (NSDictionary*)mirrorRecorderSaveState;
@end