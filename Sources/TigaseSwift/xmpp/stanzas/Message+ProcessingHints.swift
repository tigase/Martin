//
// Message+ProcessingHints.swift
//
// TigaseSwift
// Copyright (C) 2022 "Tigase, Inc." <office@tigase.com>
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
    
    public enum ProcessingHint {
        case noPermanentStore
        case noCopy
        case noStore
        case store
        
        var elemName: String {
            switch self {
            case .noPermanentStore:
                return "no-permanent-store";
            case .noStore:
                return "no-store";
            case .noCopy:
                return "no-copy";
            case .store:
                return "store";
            }
        }
        
        public func element() -> Element {
            return Element(name: elemName, xmlns: "urn:xmpp:hints");
        }
        
        public static func from(element el: Element) -> ProcessingHint? {
            guard el.xmlns == "urn:xmpp:hints" else {
                return nil;
            }
            switch el.name {
            case "no-permanent-store":
                return .noPermanentStore;
            case "no-store":
                return .noStore;
            case "no-copy":
                return .noCopy;
            case "store":
                return .store;
            default:
                return nil;
            }
        }
                
        public static func from(message: Message) -> [ProcessingHint] {
            return message.element.children.compactMap(ProcessingHint.from(element:));
        }
    }
    
    open var hints: [ProcessingHint] {
        get {
            return ProcessingHint.from(message: self);
        }
        set {
            element.removeChildren(where: { (el) -> Bool in
                return el.xmlns == "urn:xmpp:hints";
            });
            element.addChildren(newValue.map({ $0.element() }));
        }
    }
    
}
