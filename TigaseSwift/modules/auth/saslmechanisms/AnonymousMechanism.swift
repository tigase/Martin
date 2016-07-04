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

public class AnonymousMechanism: SaslMechanism {
    
    public let name = "ANONYMOUS";
    
    public init() {
        
    }
    
    public func evaluateChallenge(input: String?, sessionObject: SessionObject) throws -> String? {
        setComplete(sessionObject, completed: true);
        return nil;
    }
    
    public func isAllowedToUse(sessionObject: SessionObject) -> Bool {
        return sessionObject.userBareJid == nil;
    }
    
}