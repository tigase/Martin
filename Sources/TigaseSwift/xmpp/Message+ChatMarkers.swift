//
// Message+ChatMarkers.swift
//
// TigaseSwift
// Copyright (C) 2021 "Tigase, Inc." <office@tigase.com>
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
    
    public enum ChatMarkers {
        case received(id: String)
        case displayed(id: String)
        case acknowledged(id: String)
    
        public static let XMLNS = "urn:xmpp:chat-markers:0";
        
        public var id: String {
            switch self {
            case .received(let id):
                return id;
            case .displayed(let id):
                return id;
            case .acknowledged(let id):
                return id;
            }
        }
        
        public func element() -> Element {
            switch self {
            case .received(let id):
                return Element(name: "received", attributes: ["xmlns": ChatMarkers.XMLNS, "id": id]);
            case .displayed(let id):
                return Element(name: "displayed", attributes: ["xmlns": ChatMarkers.XMLNS, "id": id]);
            case .acknowledged(let id):
                return Element(name: "acknowledged", attributes: ["xmlns": ChatMarkers.XMLNS, "id": id]);
            }
        }
    }
    
    public var isMarkable: Bool {
        get {
            return hasChild(name: "markable", xmlns: ChatMarkers.XMLNS);
        }
        set {
            removeChildren(where: { $0.xmlns == ChatMarkers.XMLNS });
            if newValue {
                addChild(Element(name: "markable", xmlns: ChatMarkers.XMLNS));
            }
        }
    }
    
    public var chatMarkers: ChatMarkers? {
        get {
            guard let el = firstChild(xmlns: ChatMarkers.XMLNS) else {
                return nil;
            }
            
            switch el.name {
            case "received":
                guard let id = el.attribute("id") else {
                    return nil;
                }
                return .received(id: id);
            case "displayed":
                guard let id = el.attribute("id") else {
                    return nil;
                }
                return .displayed(id: id);
            case "acknowledged":
                guard let id = el.attribute("id") else {
                    return nil;
                }
                return .acknowledged(id: id);
            default:
                return nil;
            }
        }
        set {
            removeChildren(where: { $0.xmlns == ChatMarkers.XMLNS })
            if let value = newValue {
                addChild(value.element());
            }
        }

    }
}
