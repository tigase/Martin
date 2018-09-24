//
// RosterItem.swift
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
 Class holds informations about single roster entry
 */
open class RosterItem: RosterItemProtocol, CustomStringConvertible {
    
    public let jid: JID;
    public let name: String?;
    public let subscription: Subscription;
    public let ask: Bool;
    public let groups: [String];
    
    open var description: String {
        get {
            return "RosterItem{ jid=\(jid), name=\(String(describing: name)), subscription=\(subscription), groups=\(groups)}"
        }
    }
    
    public init(jid:JID, name: String?, subscription: Subscription, groups: [String] = [String](), ask: Bool = false) {
        self.jid = jid;
        self.name = name;
        self.subscription = subscription;
        self.groups = groups;
        self.ask = ask;
    }
    
    
    open func update(name: String?, subscription: Subscription, groups: [String], ask: Bool) -> RosterItem {
        return RosterItem(jid: self.jid, name: name, subscription: subscription, groups: groups, ask: ask);
    }
//    public func updateName(name: String?, )
    
    /**
     Possible subscription values allowed by XMPP specification:
     - both
     - from
     - none
     - remove
     - to
     */
    public enum Subscription: String {
        case both
        case from
        case none
        case remove
        case to
        
        public var isFrom: Bool {
            switch self {
            case .from, .both:
                return true;
            case .none, .to, .remove:
                return false;
            }
        }
        
        public var isTo: Bool {
            switch self {
            case .to, .both:
                return true;
            case .none, .from, .remove:
                return false;
            }
        }
    }
}

public protocol RosterItemProtocol: class {
    var jid:JID { get };
}
