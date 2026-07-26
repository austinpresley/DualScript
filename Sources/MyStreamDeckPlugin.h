//==============================================================================
/**
@file       MyStreamDeckPlugin.h

@brief      Stream Deck event handlers for the DualScript action

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

@end

NS_ASSUME_NONNULL_END
