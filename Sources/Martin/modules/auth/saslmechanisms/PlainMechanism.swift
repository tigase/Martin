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
    
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.stream) {
            status = .new;
        }
    }
    
    /**
     Process input data to generate response
     - parameter input: input data
     - parameter sessionObject: instance of `SessionObject`
     - returns: reponse to send to server
     */
    open func evaluateChallenge(_ input: String?, context: Context) throws -> String? {
        switch status {
        case .completed:
            throw SaslError(cause: .aborted, message: "Authentication was already completed");
        case .new:
            guard let password = context.connectionConfiguration.credentials.password else {
                throw SaslError(cause: .not_authorized, message: "Password not specified!");
            }

            let authenticationName: String? = context.connectionConfiguration.credentials.authenticationName;
            
            let userJid: BareJID = context.userBareJid;
            let authcid: String = authenticationName ?? userJid.localPart!;

            let lreq = "\0\(authcid)\0\(password)";
                
            let utf8str = lreq.data(using: String.Encoding.utf8);
            guard let base64 = utf8str?.base64EncodedString() else {
                throw SaslError(cause: .temporary_auth_failure, message: "Base64 encoding failed");
            }
            status = .inProgress;
            return base64;
        case .inProgress, .completedExpected:
            status = .completed;
            return nil;
        }
    }
    
    /**
     Check if it is allowed to use SASL PLAIN mechanism
     - parameter sessionObject: instance of `SessionObject`
     - returns: true if usage is allowed
     */
    open func isAllowedToUse(_ context: Context, features: StreamFeatures) -> Bool {
        return context.connectionConfiguration.credentials.password != nil;
    }
    

}
