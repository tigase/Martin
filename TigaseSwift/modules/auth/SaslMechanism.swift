//
// SaslMechanism.swift
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
 Protocol which must be implemented by every mechanism for SASL based 
 authentication.
 */
public protocol SaslMechanism {

    /// Mechanism name
    var name: String { get }
    
    /**
     Process input data and prepare response
     - parameter input: input data
     - parameter sessionObject: instance of `SessionObject`
     - returns: response to send to server
     */
    func evaluateChallenge(input:String?, sessionObject:SessionObject) throws -> String?
    
    /** 
     Check if mechanism may be used (ie. if needed data are available)
     - parameter sessionObject: instance of `SessionObject`
     - returns: true if possible
     */
    func isAllowedToUse(sessionObject:SessionObject) -> Bool;
    
}

public enum ClientSaslException: ErrorType {
    case BadChallenge(msg: String?)
    case WrongNonce
    case InvalidServerSignature
    case GenericError(msg: String?)
}

extension SaslMechanism {

    /**
     Check if SASL authentication is completed
     - parameter sessionObject: instance of `SessionObject`
     - returns: true if completed
     */
    public func isComplete(sessionObject:SessionObject) -> Bool {
        return sessionObject.getProperty("SASL_COMPLETE_KEY", defValue: false);
    }
    
    /**
     Mark SASL authentication as completed
     - parameter sessionObject: instance of `SessionObject`
     - parameter completed: true if authentication is completed
     */
    func setComplete(sessionObject:SessionObject, completed:Bool) {
        sessionObject.setProperty("SASL_COMPLETE_KEY", value: completed, scope: SessionObject.Scope.stream);
    }
}

