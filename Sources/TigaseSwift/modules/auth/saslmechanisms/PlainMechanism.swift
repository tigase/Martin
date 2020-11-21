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
 Mechanism implements SASL PLAIN authentication mechanism
 */
open class PlainMechanism: SaslMechanism {
    /// Name of mechanism
    public let name = "PLAIN";

    public private(set) var status: SaslMechanismStatus = .new;
    
    public func reset(scope: ResetableScope) {
        status = .new;
    }
    
    /**
     Process input data to generate response
     - parameter input: input data
     - parameter sessionObject: instance of `SessionObject`
     - returns: reponse to send to server
     */
    open func evaluateChallenge(_ input: String?, context: Context) -> String? {
        if (status == .completed) {
            return nil;
        }
        
        switch context.connectionConfiguration.credentials {
        case .password(let password, let authenticationName, _):
            let userJid: BareJID = context.userBareJid;
            let authcid: String = authenticationName ?? userJid.localPart!;

            let lreq = "\0\(authcid)\0\(password)";
            
            let utf8str = lreq.data(using: String.Encoding.utf8);
            let base64 = utf8str?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0));
            if base64 != nil {
                status = .completed;
            }

            return base64;
        default:
            status = .new;
            return nil;
        }
    }
    
    /**
     Check if it is allowed to use SASL PLAIN mechanism
     - parameter sessionObject: instance of `SessionObject`
     - returns: true if usage is allowed
     */
    open func isAllowedToUse(_ context: Context) -> Bool {
        switch context.connectionConfiguration.credentials {
        case .password(_, _, _):
            return true;
        default:
            return false;
        }
    }
    

}
