//
// JID.swift
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

public class JID : CustomStringConvertible, Equatable, StringValue {
    
    public let bareJid:BareJID!;
    public let resource:String?;
    
    public var localPart:String? {
        return self.bareJid.localPart;
    }
    
    public var domain:String! {
        return self.bareJid.domain;
    }
    
    public init(_ jid:BareJID, resource:String? = nil) {
        self.bareJid = jid;
        self.resource = resource;
    }
    
    public init(_ jid:JID) {
        self.bareJid = jid.bareJid;
        self.resource = jid.resource
    }
    
    public init(_ jid:String) {
        let idx = jid.characters.indexOf("/");
        self.resource = (idx == nil) ? nil : jid.substringFromIndex(idx!.successor())
        self.bareJid = BareJID(jid);
    }
    
    public var description : String {
        if (self.resource != nil) {
            return "\(bareJid)/\(resource!)"
        } else {
            return bareJid.description
        }
    }
    
    public var stringValue: String {
        if (self.resource != nil) {
            return "\(bareJid)/\(resource!)"
        } else {
            return bareJid.description
        }
    }
}

public func ==(lhs: JID, rhs: JID) -> Bool {
    return lhs.bareJid == rhs.bareJid && lhs.resource == rhs.resource;
}