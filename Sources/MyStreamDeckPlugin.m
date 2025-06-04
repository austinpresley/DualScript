//
//  MyStreamDeckPlugin.m
//  OSA Script  – now supports separate key-down / key-up AppleScript fields
//
//  Original plugin by Gabriel Perales
//  Modified to add scriptDown / scriptUp  2025-06-03
//

#import "MyStreamDeckPlugin.h"
#import <Foundation/Foundation.h>

#pragma mark –– Helper to run a snippet of AppleScript

/// Runs the given AppleScript source string via NSAppleScript.
/// If source is empty or nil, does nothing.
/// If there’s an error, it logs to NSLog.
static void RunOSAString(NSString *source) {
    if (source.length == 0) {
        return;
    }

    NSDictionary *errorInfo = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
    [script executeAndReturnError:&errorInfo];

    if (errorInfo) {
        NSLog(@"[OSA-Script] Execution error: %@", errorInfo);
    }
}


#pragma mark –– Plugin callbacks

@implementation MyStreamDeckPlugin

// Called when the Stream Deck app launches any monitored application.
// (We don’t need to do anything here for OSA Script.)
- (void)applicationDidLaunch:(NSString *)application
                  withContext:(NSString *)context
                    payload:(NSDictionary *)payload
                   forDevice:(NSString *)deviceID
{
    // No-op
}

// Called when the Stream Deck app terminates any monitored application.
// (We don’t need to do anything here.)
- (void)applicationDidTerminate:(NSString *)application
                     withContext:(NSString *)context
                       payload:(NSDictionary *)payload
                      forDevice:(NSString *)deviceID
{
    // No-op
}

// Called when a new Stream Deck device is connected.
- (void)deviceDidConnect:(NSString *)deviceID
         withDeviceInfo:(NSDictionary *)deviceInfo
{
    // No-op
}

// Called when a Stream Deck device is disconnected.
- (void)deviceDidDisconnect:(NSString *)deviceID
{
    // No-op
}

// Called when the user first puts this action’s button on the screen
// (e.g. switches to a profile that uses this action).
- (void)willAppearForAction:(NSString *)action
                withContext:(NSString *)context
                 withPayload:(NSDictionary *)payload
                  forDevice:(NSString *)deviceID
{
    // No-op
}

// Called when the user removes this action’s button from the screen
// (e.g. switches away from a profile that uses this action).
- (void)willDisappearForAction:(NSString *)action
                   withContext:(NSString *)context
                   withPayload:(NSDictionary *)payload
                    forDevice:(NSString *)deviceID
{
    // No-op
}


/// Called the moment the user **presses down** on the key.
/// We look up “scriptDown” in the saved settings; if empty, fall back to the old “script” key.
- (void)keyDownForAction:(NSString *)action
             withContext:(NSString *)context
              withPayload:(NSDictionary *)payload
               forDevice:(NSString *)deviceID
{
    NSDictionary *settings = payload[@"settings"] ?: @{};
    NSString *source = settings[@"scriptDown"];
    if (source.length == 0) {
        // If they left the Key Down box blank, run the old single-“script” value instead
        source = settings[@"script"];
    }
    RunOSAString(source);
}

/// Called the moment the user **releases** (lets go of) the key.
/// We look up “scriptUp” in the saved settings; if empty, fall back to the old “script” key.
- (void)keyUpForAction:(NSString *)action
           withContext:(NSString *)context
            withPayload:(NSDictionary *)payload
             forDevice:(NSString *)deviceID
{
    NSDictionary *settings = payload[@"settings"] ?: @{};
    NSString *source = settings[@"scriptUp"];
    if (source.length == 0) {
        // If they left the Key Up box blank, run the old single-“script” value instead
        source = settings[@"script"];
    }
    RunOSAString(source);
}

@end
