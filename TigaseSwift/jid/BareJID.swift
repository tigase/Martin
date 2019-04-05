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

/**
 XMPP entity address for `localpart@domainpart`
 */
open class BareJID :CustomStringConvertible, Hashable, Equatable, StringValue {
    
    /// Local part
    public let localPart:String?;
    /// Domain part
    public let domain:String;
    /// String representation
    public let stringValue:String;
    
    /**
     Create instance
     - parameter localPart: local part of JID
     - parameter domain: domain part of JID
     */
    public init(localPart: String? = nil, domain: String) {
        self.localPart = localPart;
        self.domain = domain;
        self.stringValue = BareJID.toString(localPart, domain);
    }
    
    /**
     Create instance
     
     Useful for copying/cloning of `BareJID`
     - parameter jid: instance of `BareJID`
     */
    public init(_ jid: BareJID) {
        self.localPart = jid.localPart
        self.domain = jid.domain
        self.stringValue = BareJID.toString(localPart, domain);
    }
    
    /**
     Create instance
     - parameter jid: string representation of bare JID
     */
    public init(_ jid: String) {
        let resourceIdx = jid.firstIndex(of: "/") ?? jid.endIndex;
        if let domainIdx = jid.firstIndex(of: "@") {
            localPart = String(jid.prefix(upTo: domainIdx));
            let suffixIdx = jid.index(after: domainIdx);
            domain = String((resourceIdx == jid.endIndex) ? jid.suffix(from: suffixIdx) : jid[suffixIdx..<resourceIdx]);
        } else {
            localPart = nil;
            domain = (jid.endIndex == resourceIdx) ? jid : String(jid.prefix(upTo: resourceIdx))
        }
        self.stringValue = BareJID.toString(localPart, domain);
    }
        
    /**
     Convenience constructor which allows nil as parameter
     - parameter jid: string representation of bare JID
     */
    public convenience init?(_ jid: String?) {
        guard jid != nil else {
            return nil;
        }
        self.init(jid!);
    }
    
    /**
     Create new instance of `BareJID` from instance of `JID`
     - parameter jid: JID to copy from
     */
    public init(_ jid: JID) {
        self.domain = jid.domain
        self.localPart = jid.localPart
        self.stringValue = jid.bareJid.stringValue;
    }
    
    open var description : String {
        return stringValue;
    }
    
    open func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue.lowercased());
    }
    
    fileprivate static func toString(_ localPart:String?, _ domain:String) -> String {
        if (localPart == nil) {
            return domain;
        }
        return "\(localPart!)@\(domain)"        
    }
    
}

public func ==(lhs: BareJID, rhs: BareJID) -> Bool {
    return lhs.stringValue.caseInsensitiveCompare(rhs.stringValue) == .orderedSame;
}
