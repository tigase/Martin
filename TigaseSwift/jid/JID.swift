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

/**
 XMPP entity address form `localpart@domainpart/resourcepart`
 */
open class JID : CustomStringConvertible, Hashable, Equatable, Codable, StringValue {
    
    /// BareJID part of JID
    public let bareJid:BareJID;
    /// Resouce part
    public let resource:String?;
    /// String representation of JID
    public let stringValue:String;
    /// Local part
    open var localPart:String? {
        return self.bareJid.localPart;
    }
    // Domain part
    open var domain:String! {
        return self.bareJid.domain;
    }
    
    open var withoutResource: JID {
        return JID(bareJid);
    }
    
    required public convenience init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(String.self));
    }
    
    /**
     Create instance
     - parameter jid: instance of BareJID
     - parameter resource: resource for JID
     */
    public init(_ jid: BareJID, resource: String? = nil) {
        self.bareJid = jid;
        self.resource = resource;
        self.stringValue = JID.toString(bareJid, resource);
    }
    
    /**
     Creates new instance with same values
     - parameter jid: instance of JID
     */
    public init(_ jid: JID) {
        self.bareJid = jid.bareJid;
        self.resource = jid.resource;
        self.stringValue = JID.toString(bareJid, resource);
    }
    
    /**
     Create instance from string representation of `JID`
     */
    public init(_ jid: String) {
        let idx = jid.firstIndex(of: "/");
        self.resource = (idx == nil) ? nil : String(jid.suffix(from: jid.index(after: idx!)));
        self.bareJid = BareJID(jid);
        self.stringValue = JID.toString(bareJid, resource);
    }
    
    /**
     Convenience constructor with support for `nil` string representation of `JID`
     */
    public convenience init?(_ jid: String?) {
        guard jid != nil else {
            return nil;
        }
        self.init(jid!);
    }
    
    open var description : String {
        return self.stringValue;
    }
    
    open func hash(into hasher: inout Hasher) {
        hasher.combine(bareJid);
        if resource != nil {
            hasher.combine(resource);
        }
    }
    
    open func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer();
        try container.encode(self.stringValue);
    }
    
    fileprivate static func toString(_ bareJid:BareJID, _ resource:String?) -> String {
        if (resource != nil) {
            return "\(bareJid)/\(resource!)"
        } else {
            return bareJid.description
        }
    }
}

public func ==(lhs: JID, rhs: JID) -> Bool {
    return lhs.bareJid == rhs.bareJid && lhs.resource == rhs.resource;
}
