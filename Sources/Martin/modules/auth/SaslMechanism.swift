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
public protocol SaslMechanism: AnyObject, Resetable, CustomDebugStringConvertible {

    /// Mechanism name
    var name: String { get }
    
    var status: SaslMechanismStatus { get }
    
    /**
     Process input data and prepare response
     - parameter input: input data
     - parameter sessionObject: instance of `SessionObject`
     - returns: response to send to server
     */
    func evaluateChallenge(_ input: String?, context: Context) throws -> String?
        
    /** 
     Check if mechanism may be used (ie. if needed data are available)
     - parameter context: instance of `Context`
     - returns: true if possible
     */
    func isAllowedToUse(_ context: Context, features: StreamFeatures) -> Bool;
    
}

extension SaslMechanism {
    
    public var debugDescription: String {
        return name;
    }
    
}

public protocol SaslMeachanismStreamFeaturesAware: SaslMechanism {
    
    func streamFeaturesChanged(_ streamFeatures: StreamFeatures);
    
}

public protocol Sasl2MechanismFeaturesAware: SaslMechanism {

    func feature(context: Context, sasl2: StreamFeatures.SASL2) -> Element?;
    
    func process(result: Element, context: Context);

}

public protocol Sasl2UpgradableMechanism: SaslMechanism {
    
    func evaluateUpgrade(parameters: [Element], context: Context) async throws -> Element
    
}

public enum ClientSaslException: Error {
    case badChallenge(msg: String?)
    case wrongNonce
    case invalidServerSignature
    case genericError(msg: String?)
}

public enum SaslMechanismStatus {
    case new
    case inProgress
    case completed
    case completedExpected
}
