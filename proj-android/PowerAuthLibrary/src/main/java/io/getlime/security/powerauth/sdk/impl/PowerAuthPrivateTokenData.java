/*
 * Copyright 2017 Wultra s.r.o.
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

package io.getlime.security.powerauth.sdk.impl;

import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.util.Base64;

import java.io.UnsupportedEncodingException;
import java.util.Arrays;


/**
 * The {@code PowerAuthPrivateTokenData} keeps all private data for access token.
 */
public class PowerAuthPrivateTokenData {

    /**
     * Token's symbolic name.
     */
    public final String name;
    /**
     * Token's identifier.
     */
    public final String identifier;
    /**
     * Token's secret.
     */
    public final byte[] secret;

    private static final int SECRET_LENGTH = 16;

    public PowerAuthPrivateTokenData(@NonNull String name, @NonNull String identifier, @NonNull byte[] secret) {
        this.name = name;
        this.identifier = identifier;
        this.secret = secret;
    }

    public boolean hasValidData() {
        if (name != null && identifier != null && secret != null) {
            return secret.length == SECRET_LENGTH &&
                    !identifier.isEmpty() &&
                    !name.isEmpty();
        }
        return false;
    }

    public boolean equals(Object anObject) {
        if (this == anObject) {
            return true;
        }
        if (anObject instanceof PowerAuthPrivateTokenData) {
            PowerAuthPrivateTokenData anotherToken = (PowerAuthPrivateTokenData) anObject;
            if (this.hasValidData() && anotherToken.hasValidData()) {
                return name.equals(anotherToken.name) &&
                        identifier.equals(anotherToken.identifier) &&
                        Arrays.equals(secret, anotherToken.secret);
            }
        }
        return false;
    }

    public @Nullable byte[] getSerializedData() {

        if (!this.hasValidData()) {
            return null;
        }
        final String nameB64 = Base64.encodeToString(name.getBytes(), Base64.NO_WRAP);
        final String secretB64 = Base64.encodeToString(secret, Base64.NO_WRAP);
        final String dataString = identifier + "," + secretB64 + "," + nameB64;
        try {
            return dataString.getBytes("US-ASCII");
        } catch (UnsupportedEncodingException e) {
            return null; // US-ASCII is guaranteed to be available.
        }
    }

    public static @Nullable PowerAuthPrivateTokenData deserializeWithData(@NonNull byte[] data) {

        String str;
        try {
             str = new String(data, "US-ASCII");
        } catch (UnsupportedEncodingException e) {
            return null; // US-ASCII is guaranteed to be available.
        }
        // Split into components
        final String[] components = str.split("\\,");
        if (components.length != 3) {
            return null;
        }
        final String identifier = components[0];
        final byte[] secret = Base64.decode(components[1], Base64.NO_WRAP);
        final String name = new String(Base64.decode(components[2], Base64.NO_WRAP));

        final PowerAuthPrivateTokenData tokenData = new PowerAuthPrivateTokenData(name, identifier, secret);
        return tokenData.hasValidData() ? tokenData : null;
    }
}
