//
// XMucUserElement.swift
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

//TODO: Verify this should not be a struct
/// Class holds additional information about occupant which are sent in presence from MUC room
open class XMucUserElement {
    
    public static func extract(from stanza: Stanza?) -> XMucUserElement? {
        let elem = stanza?.firstChild(name: "x", xmlns: "http://jabber.org/protocol/muc#user");
        return elem == nil ? nil : XMucUserElement(element: elem!);
    }
    
    var element: Element;

    open var affiliation: MucAffiliation {
        if let affiliationVal = element.firstChild(name: "item")?.attribute("affiliation") {
            return MucAffiliation(rawValue: affiliationVal) ?? .none;
        }
        return .none;
    }
    
    open var jid: JID? {
        if let jidVal = element.firstChild(name: "item")?.attribute("jid") {
            return JID(jidVal);
        }
        return nil;
    }
    
    open var nick: String? {
        return element.firstChild(name: "item")?.attribute("nick");
    }
    
    open var role: MucRole {
        if let roleVal = element.firstChild(name: "item")?.attribute("role") {
            return MucRole(rawValue: roleVal) ?? .none;
        }
        return .none;
    }
    
    open var statuses: [Int] {
        return element.filterChildren(name: "status").compactMap({ el -> Int? in
            guard let val = el.attribute("code") else {
                return nil;
            }
            return Int(val);
        });
    }
    
    public init?(element: Element) {
        guard element.name == "x" && element.xmlns == "http://jabber.org/protocol/muc#user" else {
            return nil;
        }
        self.element = element;
    }

}
