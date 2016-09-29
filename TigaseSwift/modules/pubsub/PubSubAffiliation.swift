//
// PubSubAffiliation.swift
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

/// Represents affiliation item
open class PubSubAffiliationElement {
    /// Instance of element
    let element: Element;
    /// Affiliation
    var affiliation: PubSubAffiliation {
        get {
            guard let val = element.getAttribute("affiliation") else {
                return .none;
            }
            return PubSubAffiliation(rawValue: val) ?? .none;
        }
        set {
            element.setAttribute("affiliation", value: newValue.rawValue);
        }
    }
    /// JID of affiliate
    var jid: JID {
        return JID(element.getAttribute("jid")!);
    }
    /// Name of node
    var node: String? {
        return element.getAttribute("node");
    }
    
    /**
     Creates affiliation item from element
     - parameter from: element with affiliation
     */
    public init?(from: Element) {
        guard from.name == "affiliation" else {
            return nil;
        }
        self.element = from;
    }
    
    /**
     Creates affiliation item for manipulation
     - parameter jid: JID of affiliate
     - parameter node: name of node
     */
    public convenience init(jid: JID, node: String?) {
        let elem = Element(name: "affiliation");
        elem.setAttribute("jid", value: jid.stringValue);
        elem.setAttribute("node", value: node);
        self.init(from: elem)!;
    }
    
}

/// Enum contains list of possible affiliations with PubSub node
public enum PubSubAffiliation: String {
    case outcast
    case none
    case member
    case publisher
    case owner
}
