//
// Message+StanzaID.swift
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

extension Message {
    
    public var originId: String? {
        get {
            return findChild(name: "origin-id", xmlns: "urn:xmpp:sid:0")?.getAttribute("id");
        }
        set {
            if let el = findChild(name: "origin-id", xmlns: "urn:xmpp:sid:0") {
                if let value = newValue {
                    el.setAttribute("id", value: value);
                } else {
                    removeChild(el);
                }
            } else if let value = newValue {
                addChild(Element(name: "origin-id", attributes: ["xmlns": "urn:xmpp:sid:0", "id": value]));
            }
        }
    }
    
    public var stanzaId: [BareJID:String]? {
        return Dictionary(uniqueKeysWithValues: getChildren(name: "stanza-id", xmlns: "urn:xmpp:sid:0").map({ el -> (BareJID, String)? in
            guard let jid = JID(el.getAttribute("by"))?.bareJid, let id = el.getAttribute("id") else {
                return nil;
            }
            return (jid, id);
        }).filter({ $0 != nil }).map({ $0! }));
    }
    
}
