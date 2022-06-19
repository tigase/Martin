//
// PubSubAffilicationItem.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

// check if this could not be a struct
open class PubSubAffiliationItem: Equatable {
    public static func == (lhs: PubSubAffiliationItem, rhs: PubSubAffiliationItem) -> Bool {
        return lhs.affiliation == rhs.affiliation && lhs.jid == rhs.jid && lhs.node == rhs.node;
    }
    

    public let affiliation: PubSubAffiliation;
    public let jid: JID;
    public let node: String;
    
    public convenience init?(from element: Element?, jid: JID) {
        guard let el = element, el.name == "affiliation", let node = el.attribute("node"), let aff = PubSubAffiliation(rawValue: el.attribute("affiliation") ?? "") else {
            return nil;
        }
        self.init(affiliation: aff, jid: jid, node: node);
    }
    
    public convenience init?(from element: Element?, node: String) {
        guard let el = element, el.name == "affiliation", let jid = JID(el.attribute("jid")), let aff = PubSubAffiliation(rawValue: el.attribute("affiliation") ?? "") else {
            return nil;
        }
        self.init(affiliation: aff, jid: jid, node: node);
    }

    public init(affiliation: PubSubAffiliation, jid: JID, node: String) {
        self.affiliation = affiliation;
        self.jid = jid;
        self.node = node;
    }
    
    public func element() -> Element {
        let elem = Element(name: "affiliation");
        elem.attribute("jid", newValue: jid.description);
        elem.attribute("node", newValue: node);
        elem.attribute("affiliation", newValue: affiliation.rawValue);
        return elem;
    }
}
