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
public struct BareJID : LosslessStringConvertible, Hashable, Equatable, Codable, Comparable, Sendable {
    
    public static func < (lhs: BareJID, rhs: BareJID) -> Bool {
        return lhs.description.compare(rhs.description) == .orderedAscending;
    }
    
    /// Local part
    public let localPart: String?;
    /// Domain part
    public let domain: String;
    
    public var description: String {
        guard let localPart = self.localPart else {
            return domain;
        }
        return "\(localPart)@\(domain)";
    }
    
    public init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(String.self));
    }
    
    /**
     Create instance
     - parameter localPart: local part of JID
     - parameter domain: domain part of JID
     */
    public init(localPart: String? = nil, domain: String) {
        self.localPart = localPart;
        self.domain = domain;
        //self.stringValue = BareJID.toString(localPart, domain);
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
            if suffixIdx < resourceIdx {
                domain = String((resourceIdx == jid.endIndex) ? jid.suffix(from: suffixIdx) : jid[suffixIdx..<resourceIdx]);
            } else {
                domain = String(jid.suffix(from: suffixIdx));
            }
        } else {
            localPart = nil;
            domain = (jid.endIndex == resourceIdx) ? jid : String(jid.prefix(upTo: resourceIdx))
        }
    }
        
    /**
     Convenience constructor which allows nil as parameter
     - parameter jid: string representation of bare JID
     */
    public init?(_ jid: String?) {
        guard let jid = jid else {
            return nil;
        }
        self.init(jid);
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer();
        try container.encode(self.description);
    }
    
    public func hash(into hasher: inout Hasher) {
        if let localPart = self.localPart?.lowercased() {
            hasher.combine(localPart);
        }
        hasher.combine(domain.lowercased());
    }
    
}

public func ==(lhs: BareJID, rhs: BareJID) -> Bool {
    // in Swift lowercased() is faster than caseInsensitiveCompare()
    guard lhs.domain.lowercased() == rhs.domain.lowercased() else {
        return false;
    }
    
    if let rPart = rhs.localPart, let lPart = lhs.localPart {
        return rPart.lowercased() == lPart.lowercased();
    } else {
        return rhs.localPart == nil && lhs.localPart == nil;
    }
}
