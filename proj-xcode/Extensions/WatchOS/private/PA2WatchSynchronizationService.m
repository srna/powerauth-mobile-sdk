/**
 * Copyright 2018 Lime - HighTech Solutions s.r.o.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "PA2WatchSynchronizationService.h"

#import "PA2WCSessionPacket_ActivationStatus.h"
#import "PA2WCSessionPacket_TokenData.h"
#import "PA2WCSessionPacket_Success.h"

#import "PA2Keychain.h"
#import "PA2PrivateMacros.h"
#import "PA2ErrorConstants.h"
#import "PA2PrivateTokenKeychainStore.h"

@implementation PA2WatchSynchronizationService
{
	PA2Keychain * _statusKeychain;
	PA2Keychain * _tokenStoreKeychain;
}

#pragma mark - Init & Singleton

- (id) init
{
	self = [super init];
	if (self) {
		PA2KeychainConfiguration * keychainConfiguration = [PA2KeychainConfiguration sharedInstance];
		_statusKeychain = [[PA2Keychain alloc] initWithIdentifier:keychainConfiguration.keychainInstanceName_Status];
		_tokenStoreKeychain = [[PA2Keychain alloc] initWithIdentifier:keychainConfiguration.keychainInstanceName_TokenStore];
	}
	return self;
}

+ (PA2WatchSynchronizationService*) sharedInstance
{
	static dispatch_once_t onceToken;
	static PA2WatchSynchronizationService * instance = nil;
	dispatch_once(&onceToken, ^{
		instance = [[PA2WatchSynchronizationService alloc] init];
	});
	return instance;
}


#pragma mark - Public methods

- (NSString*) activationIdForSessionInstanceId:(nonnull NSString*)sessionInstanceId
{
	if (sessionInstanceId.length > 0) {
		NSData * statusData = [_statusKeychain dataForKey:sessionInstanceId status:NULL];
		if (statusData.length > 0) {
			return [[NSString alloc] initWithData:statusData encoding:NSUTF8StringEncoding];
		}
	}
	return nil;
}

- (void) updateActivationId:(nullable NSString*)activationId forSessionInstanceId:(nonnull NSString*)sessionInstanceId
{
	if (sessionInstanceId.length > 0) {
		NSData * currentData = [_statusKeychain dataForKey:sessionInstanceId status:NULL];
		if (activationId) {
			NSData * activationIdData = [activationId dataUsingEncoding:NSUTF8StringEncoding];
			if (currentData) {
				if (![currentData isEqualToData:activationIdData]) {
					[_statusKeychain updateValue:activationIdData forKey:sessionInstanceId];
					PALog(@"PA2WatchSynchronizationService: Session with instanceId %@' is now activated (with different activation ID).", sessionInstanceId);
				}
			} else {
				[_statusKeychain addValue:activationIdData forKey:sessionInstanceId];
				PALog(@"PA2WatchSynchronizationService: Session with instanceId %@' is now activated.", sessionInstanceId);
			}
		} else {
			// Removing activation status
			if (currentData) {
				[_statusKeychain deleteDataForKey:sessionInstanceId];
				PALog(@"PA2WatchSynchronizationService: Session with instanceId %@' is no longer activated.", sessionInstanceId);
			}
		}
	} else {
		PALog(@"PA2WatchSynchronizationService: ERROR: Session's instanceId is empty.");
	}
}


#pragma mark - PA2WCSessionDataHandler

- (BOOL) canProcessPacket:(PA2WCSessionPacket *)packet
{
	return [packet.target hasPrefix:PA2WCSessionPacket_SESSION_TARGET] ||
		   [packet.target hasPrefix:PA2WCSessionPacket_TOKEN_TARGET];
}

- (PA2WCSessionPacket*) sessionManager:(PA2WCSessionManager*)manager responseForPacket:(PA2WCSessionPacket*)packet
{
	if ([packet.target hasPrefix:PA2WCSessionPacket_SESSION_TARGET]) {
		return [self processSessionStatusPacket:packet];
	} else if ([packet.target hasPrefix:PA2WCSessionPacket_TOKEN_TARGET]) {
		return [self processTokenPacket:packet];
	}
	NSError * error = PA2MakeError(PA2ErrorCodeWatchConnectivity, @"PA2WatchSynchronizationService: Can't process packet.");
	return [PA2WCSessionPacket packetWithError:error];
}


#pragma mark -

- (PA2WCSessionPacket*) processSessionStatusPacket:(PA2WCSessionPacket*)packet
{
	// Handle status packet received from iPhone
	NSString * errorMessage = nil;
	do {
		// Deserialize payload & instanceId
		PA2WCSessionPacket_ActivationStatus * status = [[PA2WCSessionPacket_ActivationStatus alloc] initWithDictionary:packet.sourceData];
		if (![status validatePacketData]) {
			errorMessage =  [NSString stringWithFormat:@"PA2WatchSynchronizationService: Received status is invalid. Target: %@", packet.target];
			break;
		}
		NSString * instanceId = [packet.target substringFromIndex:PA2WCSessionPacket_SESSION_TARGET.length];
		if (instanceId.length == 0) {
			errorMessage = @"PA2WatchSynchronizationService: Target doesn't contain session instance identifier.";
			break;
		}
		// Process command
		NSString * command = status.command;
		if ([command isEqualToString:PA2WCSessionPacket_CMD_SESSION_PUT]) {
			// Update session status
			[self updateActivationId:status.activationId forSessionInstanceId:instanceId];
			//
		} else {
			//
			errorMessage = [NSString stringWithFormat:@"PA2WatchSynchronizationService: Unsupported command '%@'", command];
			break;
		}
		
	} while (false);
	
	if (errorMessage) {
		// Return reply packet with error.
		NSError * error = [NSError errorWithDomain:PA2ErrorDomain code:PA2ErrorCodeWatchConnectivity userInfo:@{ NSLocalizedDescriptionKey: errorMessage }];
		return [PA2WCSessionPacket packetWithError:error];
	}
	// Everything looks great, return Success packet.
	return [PA2WCSessionPacket packetWithSuccess];
}


- (PA2WCSessionPacket*) processTokenPacket:(PA2WCSessionPacket*)packet
{
	NSString * errorMessage = nil;
	do {
		PA2WCSessionPacket_TokenData * tokenData = [[PA2WCSessionPacket_TokenData alloc] initWithDictionary:packet.sourceData];
		if (![tokenData validatePacketData]) {
			errorMessage =  [NSString stringWithFormat:@"PA2WatchSynchronizationService: Received token data is invalid. Target: %@", packet.target];
			break;
		}
		NSString * instanceId = [packet.target substringFromIndex:PA2WCSessionPacket_TOKEN_TARGET.length];
		NSString * keychainIdentifier = [PA2PrivateTokenKeychainStore identifierForTokenName:tokenData.tokenName forInstanceId:instanceId];
		if (!keychainIdentifier) {
			errorMessage = @"PA2WatchSynchronizationService: Target doesn't contain token store instance identifier.";
			break;
		}
		NSString * command = tokenData.command;
		if ([command isEqualToString:PA2WCSessionPacket_CMD_TOKEN_PUT]) {
			// Check whether the data blob is really a serialized token data (we don't need that object)
			NSData * tokenPrivateData = tokenData.tokenData;
			if ([PA2PrivateTokenData deserializeWithData:tokenPrivateData] != nil) {
				// Add or Update entry in the keychain
				if ([_tokenStoreKeychain containsDataForKey:keychainIdentifier]) {
					[_tokenStoreKeychain updateValue:tokenPrivateData forKey:keychainIdentifier];
				} else {
					[_tokenStoreKeychain addValue:tokenPrivateData forKey:keychainIdentifier];
				}
				// Success...
				break;
				
			} else {
				errorMessage = @"PA2WatchSynchronizationService: Token data deserialization failed.";
				break;
			}
		} else if ([command isEqualToString:PA2WCSessionPacket_CMD_TOKEN_REMOVE]) {
			// Try to remove data
			[_tokenStoreKeychain deleteDataForKey:keychainIdentifier];
			// Success...
			break;
			
		} else {
			//
			errorMessage = [NSString stringWithFormat:@"PA2WatchSynchronizationService: Unsupported command '%@'", command];
			break;
		}
		
	} while (false);

	if (errorMessage) {
		// Return reply packet with error.
		NSError * error = [NSError errorWithDomain:PA2ErrorDomain code:PA2ErrorCodeWatchConnectivity userInfo:@{ NSLocalizedDescriptionKey: errorMessage }];
		return [PA2WCSessionPacket packetWithError:error];
	}
	// Everything looks great, return Success packet.
	return [PA2WCSessionPacket packetWithSuccess];
}



@end
