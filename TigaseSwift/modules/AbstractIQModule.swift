//
// AbstractIQModule.swift
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
 Extension of `XmppModule` with helper methods for implementing
 modules reacting on `Iq` stanzas
 */
public protocol AbstractIQModule: XmppModule {
    
    /**
     Will be called on `<iq type=\"get\"/>'
     - parameter stanza: stanza to process
     */
    func processGet(stanza:Stanza) throws;
    
    /**
     Will be called on `<iq type=\"set\"/>'
     - parameter stanza: stanza to process
     */
    func processSet(stanza:Stanza) throws;
    
}

extension AbstractIQModule {
    
    public func process(stanza: Stanza) throws {
        if let type = stanza.type {
            switch type {
            case .set:
                try processSet(stanza: stanza);
                return;
            case .get:
                try processGet(stanza: stanza);
                return;
            default:
                break;
            }
        }
        throw ErrorCondition.bad_request;
    }
    
}
