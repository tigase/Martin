//
// PlainMechanism.swift
//
// TigaseSwift
// Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License,
// or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. Look for COPYING file in the top folder.
// If not, see http://www.gnu.org/licenses/.
//

import Foundation

/**
 Mechanism implements SASL PLAIN mechanism
 */
public class PlainMechanism: SaslMechanism {
    /// Name of mechanism
    public let name = "PLAIN";

    /**
     Process input data to generate response
     - parameter input: input data
     - parameter sessionObject: instance of `SessionObject`
     - returns: reponse to send to server
     */
    public func evaluateChallenge(input: String?, sessionObject: SessionObject) -> String? {
        if (isComplete(sessionObject)) {
            return nil;
        }
        
        let callback:CredentialsCallback = sessionObject.getProperty(AuthModule.CREDENTIALS_CALLBACK) ?? DefaultCredentialsCallback(sessionObject: sessionObject);
        
        let userJid:BareJID = sessionObject.getProperty(SessionObject.USER_BARE_JID)!;
        let authcid:String = sessionObject.getProperty(AuthModule.LOGIN_USER_NAME_KEY) ?? userJid.localPart!;
        let credential = callback.getCredential();
        
        let lreq = "\0\(authcid)\0\(credential)";
        
        let utf8str = lreq.dataUsingEncoding(NSUTF8StringEncoding);
        let base64 = utf8str?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0));
        if base64 != nil {
            setComplete(sessionObject, completed: true);
        }
        return base64;
    }
    
    /**
     Check if it is allowed to use SASL PLAIN mechanism
     - parameter sessionObject: instance of `SessionObject`
     - returns: true if usage is allowed
     */
    public func isAllowedToUse(sessionObject: SessionObject) -> Bool {
        return sessionObject.hasProperty(SessionObject.PASSWORD)
            && sessionObject.hasProperty(SessionObject.USER_BARE_JID);
    }
    

}