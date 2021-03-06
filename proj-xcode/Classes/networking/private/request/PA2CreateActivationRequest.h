/**
 * Copyright 2016 Wultra s.r.o.
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

#import "PA2Codable.h"

@class PA2EncryptedRequest;

/**
 Request for '/pa/activation/create' endpoint.
 */
@interface PA2CreateActivationRequest : NSObject <PA2Encodable>

/**
 Contains type of activation. Currenty, only "CODE" and "CUSTOM" is expected.
 */
@property (nonatomic, strong, readonly) NSString * activationType;
/**
 Identity attributes, may contain activation code, or complete custom,
 application specific attributes.
 */
@property (nonatomic, strong, readonly) NSDictionary<NSString*, NSString*>* identityAttributes;
/**
 Property contains encrypted, private data, required for activation creation.
 The encrypted `PA2CreateActivationRequestData` object is expected.
 */
@property (nonatomic, strong) PA2EncryptedRequest * activationData;

/**
 Returns a new instnace of object, prepared for standard activation. The `activationData`
 property has to be set to the object.
 */
+ (instancetype) standardActivationWithCode:(NSString*)activationCode;
/**
 Returns a new instance of object, prepared for a custom activation. The `activationData`
 property has to be set to the object.
 */
+ (instancetype) customActivationWithIdentityAttributes:(NSDictionary<NSString*, NSString*>*)attributes;
/**
 Returns a new instance of object, prepared for a recovery activation. The `activationData`
 property has to be set to the object.
 */
+ (instancetype) recoveryActivationWithCode:(NSString*)recoveryCode puk:(NSString*)puk;

@end

