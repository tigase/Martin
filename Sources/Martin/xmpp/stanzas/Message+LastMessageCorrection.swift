//
// Message+LastMessageCorrection.swift
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
    
    public var lastMessageCorrectionId: String? {
        get {
            return element.firstChild(name: "replace", xmlns: "urn:xmpp:message-correct:0")?.attribute("id");
        }
        set {
            element.removeChildren(name: "replace", xmlns: "urn:xmpp:message-correct:0");
            if let val = newValue {
                let el = Element(name: "replace", xmlns: "urn:xmpp:message-correct:0");
                el.attribute("id", newValue: val)
                element.addChild(el);
            }
        }
    }
    
}

extension CapabilitiesModule.AdditionalFeatures {
    
    public static let lastMessageCorrection = CapabilitiesModule.AdditionalFeatures(rawValue: "urn:xmpp:message-correct:0");
    
}
