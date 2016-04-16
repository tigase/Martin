//
// BareJID.swift
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

public class BareJID :CustomStringConvertible, Equatable, StringValue {
    
    public let localPart:String?;
    public let domain:String!;
    
    public init(_ jid:BareJID) {
        self.localPart = jid.localPart
        self.domain = jid.domain
    }
    
    public init(_ jid:String) {
        var idx = jid.characters.indexOf("/");
        let bareJid = (idx == nil) ? jid : jid.substringToIndex(idx!);
        idx = bareJid.characters.indexOf("@");
        localPart = (idx == nil) ? nil : bareJid.substringToIndex(idx!);
        domain = (idx == nil) ? bareJid : bareJid.substringFromIndex(idx!.successor());
    }
    
    public init (_ jid:JID) {
        self.domain = jid.domain
        self.localPart = jid.localPart
    }
    
    public var description : String {
        if (localPart == nil) {
            return domain;
        }
        return "\(localPart!)@\(domain)"
    }
    
    public var stringValue : String {
        if (localPart == nil) {
            return domain;
        }
        return "\(localPart!)@\(domain)"        
    }
    
}

public func ==(lhs: BareJID, rhs: BareJID) -> Bool {
    return lhs.domain == rhs.domain && lhs.localPart == rhs.localPart;
}
