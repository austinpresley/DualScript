//==============================================================================
/**
@file       MyStreamDeckPlugin.h

@brief      A Stream Deck plugin displaying the number of unread emails in Apple's Mail

@copyright  (c) 2018, Corsair Memory, Inc.
			This source code is licensed under the MIT-style license found in the LICENSE file.

**/
//==============================================================================

#import <Foundation/Foundation.h>
#import "ESDEventsProtocol.h"

@class ESDConnectionManager;


NS_ASSUME_NONNULL_BEGIN

@interface MyStreamDeckPlugin : NSObject <ESDEventsProtocol>

@property (weak) ESDConnectionManager *connectionManager;
/// Maps a device ID to the context that is currently front-most on that device.
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSString*> *activeContextForDevice;

/// Returns YES if the given context is the front-most action on the specified device.
- (BOOL)isFrontMostContext:(NSString *)context onDevice:(NSString *)deviceID;

- (void)keyDownForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;
- (void)keyUpForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;
- (void)willAppearForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;
- (void)willDisappearForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;

// Encoder-related events (Stream Deck+) – gated by isActiveOnDial.
- (void)dialRotateForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;
- (void)dialDownForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;
- (void)dialUpForAction:(NSString *)action withContext:(id)context withPayload:(NSDictionary *)payload forDevice:(NSString *)deviceID;

- (void)deviceDidConnect:(NSString *)deviceID withDeviceInfo:(NSDictionary *)deviceInfo;
- (void)deviceDidDisconnect:(NSString *)deviceID;

- (void)applicationDidLaunch:(NSDictionary *)applicationInfo;
- (void)applicationDidTerminate:(NSDictionary *)applicationInfo;

@end

NS_ASSUME_NONNULL_END

