//
// AnonymousMechanism.swift
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
 Mechanism implements SASL ANONYMOUS authentication mechanism
 */

open class AnonymousMechanism: SaslMechanism {
    
    public let name = "ANONYMOUS";
    
    public private(set) var status: SaslMechanismStatus = .new;
        
    public init() {
        
    }
    
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.stream) {
            status = .new;
        }
    }
    
    open func evaluateChallenge(_ input: String?, context: Context) throws -> String? {
        switch status {
        case .new:
            status = .inProgress;
        case .inProgress:
            status = .completed;
        default:
            throw SaslError(cause: .aborted, message: nil);
        }
        return nil;
    }
    
    open func isAllowedToUse(_ context: Context, features: StreamFeatures) -> Bool {
        return context.connectionConfiguration.credentials.isEmpty;
    }
    
}
