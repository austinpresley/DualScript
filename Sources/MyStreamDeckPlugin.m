//==============================================================================
/**
@file       MyStreamDeckPlugin.m

@brief      Stream Deck event handlers for the DualScript action

@copyright  (c) 2018, Corsair Memory, Inc.
			This source code is licensed under the MIT-style license found in the LICENSE file.

**/
//==============================================================================

@import OSAKit;

#import "MyStreamDeckPlugin.h"

#import "ESDConnectionManager.h"
#import "ESDSDKDefines.h"

static NSString * const kDualScriptDefaultLanguage = @"AppleScript";
static NSString * const kDualScriptJavaScriptLanguage = @"JavaScript";
static NSString * const kDualScriptSettingLanguage = @"language";
static NSString * const kDualScriptSettingScriptDown = @"scriptDown";
static NSString * const kDualScriptSettingScriptUp = @"scriptUp";
static NSString * const kDualScriptLegacySettingScript = @"script";
static NSString * const kDualScriptLegacySettingScriptText = @"scriptText";
static NSString * const kDualScriptTriggerKey = @"trigger";
static NSString * const kDualScriptTriggerTestDown = @"testDown";
static NSString * const kDualScriptTriggerTestUp = @"testUp";
static NSString * const kDualScriptTriggerValidateDown = @"validateDown";
static NSString * const kDualScriptTriggerValidateUp = @"validateUp";
static NSString * const kDualScriptMessageTypeKey = @"type";
static NSString * const kDualScriptMessageExecutionResult = @"executionResult";
static NSString * const kDualScriptMessageValidationResult = @"validationResult";
static NSString * const kDualScriptMessagePhaseKey = @"phase";
static NSString * const kDualScriptMessageSuccessKey = @"success";
static NSString * const kDualScriptMessageTextKey = @"message";
static NSString * const kDualScriptMessageRequestIDKey = @"requestID";
static NSString * const kDualScriptMessageRangeLocationKey = @"rangeLocation";
static NSString * const kDualScriptMessageRangeLengthKey = @"rangeLength";
static NSString * const kDualScriptPhaseDown = @"down";
static NSString * const kDualScriptPhaseUp = @"up";

typedef NS_ENUM(NSInteger, DualScriptKeyState)
{
	DualScriptKeyStateIdle = 0,
	DualScriptKeyStateRunning = 1,
	DualScriptKeyStateError = 2
};

@interface MyStreamDeckPlugin ()

@property (strong) dispatch_queue_t scriptExecutionQueue;

@end

@implementation MyStreamDeckPlugin

- (instancetype)init
{
	self = [super init];
	if (self)
	{
		_scriptExecutionQueue = dispatch_queue_create("com.apresley.dualscript.execution", DISPATCH_QUEUE_SERIAL);
	}
	return self;
}

- (NSString *)stringValueForObject:(id)object
{
	return [object isKindOfClass:[NSString class]] ? object : @"";
}

- (BOOL)stringHasContent:(NSString *)value
{
	return [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0;
}

- (NSString *)normalizedLanguageName:(NSString *)languageName
{
	return [languageName isEqualToString:kDualScriptJavaScriptLanguage] ? kDualScriptJavaScriptLanguage : kDualScriptDefaultLanguage;
}

- (NSDictionary<NSString *, NSString *> *)normalizedSettingsFromPayloadContainer:(NSDictionary *)payloadContainer
{
	NSDictionary *rawSettings = payloadContainer[@kESDSDKPayloadSettings];
	if (![rawSettings isKindOfClass:[NSDictionary class]])
	{
		rawSettings = payloadContainer ?: @{};
	}

	NSString *language = [self normalizedLanguageName:[self stringValueForObject:rawSettings[kDualScriptSettingLanguage]]];
	NSString *scriptDown = [self stringValueForObject:rawSettings[kDualScriptSettingScriptDown]];
	NSString *scriptUp = [self stringValueForObject:rawSettings[kDualScriptSettingScriptUp]];

	if (![self stringHasContent:scriptDown])
	{
		NSString *legacyInlineScript = [self stringValueForObject:rawSettings[kDualScriptLegacySettingScriptText]];
		if ([self stringHasContent:legacyInlineScript])
		{
			scriptDown = legacyInlineScript;
		}
	}

	if (![self stringHasContent:scriptDown])
	{
		NSString *legacyScript = [self stringValueForObject:rawSettings[kDualScriptLegacySettingScript]];
		if ([self stringHasContent:legacyScript])
		{
			scriptDown = legacyScript;
		}
	}

	return @{
		kDualScriptSettingLanguage: language,
		kDualScriptSettingScriptDown: scriptDown,
		kDualScriptSettingScriptUp: scriptUp
	};
}

- (NSString *)displayNameForPhase:(NSString *)phase
{
	return [phase isEqualToString:kDualScriptPhaseUp] ? @"Key Up" : @"Key Down";
}

- (NSString *)scriptSourceForPhase:(NSString *)phase settings:(NSDictionary<NSString *, NSString *> *)settings
{
	return [phase isEqualToString:kDualScriptPhaseUp] ? settings[kDualScriptSettingScriptUp] : settings[kDualScriptSettingScriptDown];
}

- (void)updateKeyState:(DualScriptKeyState)state forContext:(NSString *)context
{
	if ([context length] == 0)
	{
		return;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.connectionManager setState:@(state) forContext:context];
	});
}

- (OSALanguage *)scriptLanguageForName:(NSString *)languageName
{
	OSALanguage *language = [OSALanguage languageForName:languageName];
	if (language == nil)
	{
		language = [OSALanguage languageForName:kDualScriptDefaultLanguage];
	}
	if (language == nil)
	{
		language = [OSALanguage defaultLanguage];
	}
	return language;
}

- (NSString *)formattedErrorDescription:(NSDictionary<NSString *, id> *)errorInfo
{
	NSString *message = [self stringValueForObject:errorInfo[OSAScriptErrorBriefMessageKey]];
	if (![self stringHasContent:message])
	{
		message = [self stringValueForObject:errorInfo[OSAScriptErrorMessageKey]];
	}
	if (![self stringHasContent:message])
	{
		message = [self stringValueForObject:errorInfo[NSLocalizedDescriptionKey]];
	}
	if (![self stringHasContent:message])
	{
		message = @"Script execution failed.";
	}

	NSValue *rangeValue = errorInfo[OSAScriptErrorRangeKey];
	if ([rangeValue isKindOfClass:[NSValue class]])
	{
		NSRange range = [rangeValue rangeValue];
		if (range.location != NSNotFound)
		{
			return [NSString stringWithFormat:@"%@ (chars %lu-%lu)", message, (unsigned long)range.location + 1, (unsigned long)(NSMaxRange(range))];
		}
	}

	return message;
}

- (void)sendPropertyInspectorResultForContext:(NSString *)context
										 type:(NSString *)type
										phase:(NSString *)phase
									  success:(BOOL)success
									   message:(NSString *)message
									 requestID:(nullable NSString *)requestID
									 errorInfo:(nullable NSDictionary<NSString *, id> *)errorInfo
{
	if ([context length] == 0)
	{
		return;
	}

	NSMutableDictionary *payload = [@{
		kDualScriptMessageTypeKey: kDualScriptMessageExecutionResult,
		kDualScriptMessagePhaseKey: phase,
		kDualScriptMessageSuccessKey: @(success),
		kDualScriptMessageTextKey: message ?: @""
	} mutableCopy];

	payload[kDualScriptMessageTypeKey] = type;
	if ([requestID length] > 0)
	{
		payload[kDualScriptMessageRequestIDKey] = requestID;
	}

	NSValue *rangeValue = errorInfo[OSAScriptErrorRangeKey];
	if ([rangeValue isKindOfClass:[NSValue class]])
	{
		NSRange range = [rangeValue rangeValue];
		if (range.location != NSNotFound)
		{
			payload[kDualScriptMessageRangeLocationKey] = @(range.location);
			payload[kDualScriptMessageRangeLengthKey] = @(range.length);
		}
	}

	[self.connectionManager sendToPropertyInspector:payload withContext:context];
}

- (nullable OSAScript *)compiledScriptFromSource:(NSString *)source
										language:(NSString *)languageName
										   error:(NSDictionary<NSString *, id> * __autoreleasing *)errorInfo
{
	OSAScript *script = [[OSAScript alloc] initWithSource:source language:[self scriptLanguageForName:languageName]];
	if (![script compileAndReturnError:errorInfo])
	{
		return nil;
	}

	return script;
}

- (void)reportExecutionFailureForPhase:(NSString *)phase
							   language:(NSString *)language
								context:(NSString *)context
								  error:(NSDictionary<NSString *, id> *)errorInfo
				 notifyPropertyInspector:(BOOL)notifyPropertyInspector
{
	NSString *phaseName = [self displayNameForPhase:phase];
	NSString *errorDescription = [self formattedErrorDescription:errorInfo];
	NSString *logMessage = [NSString stringWithFormat:@"DualScript %@ (%@) failed: %@", phaseName, language, errorDescription];

	NSLog(@"%@", logMessage);
	[self.connectionManager logMessage:logMessage];
	[self updateKeyState:DualScriptKeyStateError forContext:context];

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.connectionManager showAlertForContext:context];
		if (notifyPropertyInspector)
		{
			[self sendPropertyInspectorResultForContext:context
												 type:kDualScriptMessageExecutionResult
												phase:phase
											  success:NO
											   message:errorDescription
											 requestID:nil
											 errorInfo:errorInfo];
		}
	});
}

- (void)executeScriptSource:(NSString *)source
				   language:(NSString *)languageName
					  phase:(NSString *)phase
					context:(NSString *)context
	 notifyPropertyInspector:(BOOL)notifyPropertyInspector
{
	if (![self stringHasContent:source])
	{
		if (notifyPropertyInspector)
		{
			NSString *message = [NSString stringWithFormat:@"%@ script is empty.", [self displayNameForPhase:phase]];
			[self sendPropertyInspectorResultForContext:context
												 type:kDualScriptMessageExecutionResult
												phase:phase
											  success:NO
											   message:message
											 requestID:nil
											 errorInfo:nil];
		}
		return;
	}

	NSString *normalizedLanguage = [self normalizedLanguageName:languageName];
	[self updateKeyState:DualScriptKeyStateRunning forContext:context];

	dispatch_async(self.scriptExecutionQueue, ^{
		@autoreleasepool
		{
			NSDictionary<NSString *, id> *errorInfo = nil;
			OSAScript *script = [self compiledScriptFromSource:source language:normalizedLanguage error:&errorInfo];

			if (script == nil)
			{
				[self reportExecutionFailureForPhase:phase
											language:normalizedLanguage
											 context:context
											   error:errorInfo ?: @{}
								 notifyPropertyInspector:notifyPropertyInspector];
				return;
			}

			errorInfo = nil;
			[script executeAndReturnError:&errorInfo];
			if (errorInfo != nil)
			{
				[self reportExecutionFailureForPhase:phase
											language:normalizedLanguage
											 context:context
											   error:errorInfo
								 notifyPropertyInspector:notifyPropertyInspector];
				return;
			}

			[self updateKeyState:DualScriptKeyStateIdle forContext:context];

			if (notifyPropertyInspector)
			{
				NSString *message = [NSString stringWithFormat:@"%@ test completed.", [self displayNameForPhase:phase]];
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.connectionManager showOKForContext:context];
					[self sendPropertyInspectorResultForContext:context
														 type:kDualScriptMessageExecutionResult
														phase:phase
													  success:YES
													   message:message
													 requestID:nil
													 errorInfo:nil];
				});
			}
		}
	});
}

- (void)validateScriptSource:(NSString *)source
					language:(NSString *)languageName
					   phase:(NSString *)phase
					 context:(NSString *)context
				   requestID:(NSString *)requestID
{
	if (![self stringHasContent:source])
	{
		[self sendPropertyInspectorResultForContext:context
											 type:kDualScriptMessageValidationResult
											phase:phase
										  success:YES
										   message:@"Script is empty."
										 requestID:requestID
										 errorInfo:nil];
		return;
	}

	NSString *normalizedLanguage = [self normalizedLanguageName:languageName];

	dispatch_async(self.scriptExecutionQueue, ^{
		@autoreleasepool
		{
			NSDictionary<NSString *, id> *errorInfo = nil;
			OSAScript *script = [self compiledScriptFromSource:source language:normalizedLanguage error:&errorInfo];
			if (script == nil)
			{
				NSString *message = [self formattedErrorDescription:errorInfo ?: @{}];
				[self sendPropertyInspectorResultForContext:context
													 type:kDualScriptMessageValidationResult
													phase:phase
												  success:NO
												   message:message
												 requestID:requestID
												 errorInfo:errorInfo];
				return;
			}

			NSString *message = [NSString stringWithFormat:@"%@ syntax is valid.", normalizedLanguage];
			#pragma unused(script)
			[self sendPropertyInspectorResultForContext:context
												 type:kDualScriptMessageValidationResult
												phase:phase
											  success:YES
											   message:message
											 requestID:requestID
											 errorInfo:nil];
		}
	});
}

- (void)handleExecutionForPhase:(NSString *)phase
						payload:(NSDictionary *)payload
						context:(NSString *)context
	   notifyPropertyInspector:(BOOL)notifyPropertyInspector
{
	NSDictionary<NSString *, NSString *> *settings = [self normalizedSettingsFromPayloadContainer:payload];
	NSString *source = [self scriptSourceForPhase:phase settings:settings];
	NSString *language = settings[kDualScriptSettingLanguage];

	[self executeScriptSource:source
					 language:language
						phase:phase
					  context:context
	   notifyPropertyInspector:notifyPropertyInspector];
}

- (void)handleValidationForPhase:(NSString *)phase
						 payload:(NSDictionary *)payload
						 context:(NSString *)context
{
	NSDictionary<NSString *, NSString *> *settings = [self normalizedSettingsFromPayloadContainer:payload];
	NSString *source = [self scriptSourceForPhase:phase settings:settings];
	NSString *language = settings[kDualScriptSettingLanguage];
	NSString *requestID = [self stringValueForObject:payload[kDualScriptMessageRequestIDKey]];

	[self validateScriptSource:source
					  language:language
						 phase:phase
					   context:context
					 requestID:requestID];
}

- (void)keyDownForAction:(NSString *)action
			 withContext:(id)context
			 withPayload:(NSDictionary *)payload
			   forDevice:(NSString *)deviceID
{
	#pragma unused(action, deviceID)
	[self handleExecutionForPhase:kDualScriptPhaseDown payload:payload context:context notifyPropertyInspector:NO];
}

- (void)keyUpForAction:(NSString *)action
		   withContext:(id)context
		   withPayload:(NSDictionary *)payload
			 forDevice:(NSString *)deviceID
{
	#pragma unused(action, deviceID)
	[self handleExecutionForPhase:kDualScriptPhaseUp payload:payload context:context notifyPropertyInspector:NO];
}

- (void)sendToPluginForAction:(NSString *)action
				  withContext:(id)context
				  withPayload:(NSDictionary *)payload
					forDevice:(NSString *)deviceID
{
	#pragma unused(action, deviceID)
	NSString *trigger = [self stringValueForObject:payload[kDualScriptTriggerKey]];
	if ([trigger isEqualToString:kDualScriptTriggerTestDown])
	{
		[self handleExecutionForPhase:kDualScriptPhaseDown payload:payload context:context notifyPropertyInspector:YES];
	}
	else if ([trigger isEqualToString:kDualScriptTriggerTestUp])
	{
		[self handleExecutionForPhase:kDualScriptPhaseUp payload:payload context:context notifyPropertyInspector:YES];
	}
	else if ([trigger isEqualToString:kDualScriptTriggerValidateDown])
	{
		[self handleValidationForPhase:kDualScriptPhaseDown payload:payload context:context];
	}
	else if ([trigger isEqualToString:kDualScriptTriggerValidateUp])
	{
		[self handleValidationForPhase:kDualScriptPhaseUp payload:payload context:context];
	}
}

- (void)willAppearForAction:(NSString *)action
				withContext:(id)context
				withPayload:(NSDictionary *)payload
				  forDevice:(NSString *)deviceID
{
	#pragma unused(action, payload, deviceID)
	[self updateKeyState:DualScriptKeyStateIdle forContext:context];
}

- (void)willDisappearForAction:(NSString *)action
				   withContext:(id)context
				   withPayload:(NSDictionary *)payload
					 forDevice:(NSString *)deviceID
{
	#pragma unused(action, context, payload, deviceID)
}

- (void)deviceDidConnect:(NSString *)deviceID withDeviceInfo:(NSDictionary *)deviceInfo
{
	#pragma unused(deviceID, deviceInfo)
}

- (void)deviceDidDisconnect:(NSString *)deviceID
{
	#pragma unused(deviceID)
}

- (void)applicationDidLaunch:(NSDictionary *)applicationInfo
{
	#pragma unused(applicationInfo)
}

- (void)applicationDidTerminate:(NSDictionary *)applicationInfo
{
	#pragma unused(applicationInfo)
}

@end
