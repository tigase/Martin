//
// DataForm+Layout.swift
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

extension DataForm {
    
    public struct Page {
        
        public enum Item {
            case text(String)
            case fieldref(String)
            case reportedref
            case section([Item])

            public static func from(element: Element) -> Item? {
                switch element.name {
                case "text":
                    return .text(element.value ?? "")
                case "fieldref":
                    guard let ref = element.getAttribute("var") else {
                        return nil;
                    }
                    return .fieldref(ref);
                case "reportedref":
                    return .reportedref
                case "section":
                    return .section(element.mapChildren(transform: Item.from(element:)));
                default:
                    return nil;
                }
            }

            public func element() -> Element {
                switch self {
                case .text(let text):
                    return Element(name: "text", cdata: text);
                case .fieldref(let ref):
                    let el = Element(name: "fieldref");
                    el.setAttribute("var", value: ref);
                    return el;
                case .reportedref:
                    return Element(name: "reportedref");
                case .section(let items):
                    let el = Element(name: "section");
                    el.addChildren(items.map({ $0.element() }));
                    return el;
                }
            }
        }
        
        public let items: [Item];
        
        public init?(element: Element) {
            guard element.name == "page" && element.xmlns == "http://jabber.org/protocol/xdata-layout" else {
                return nil;
            }
            
            self.items = element.mapChildren(transform: Item.from(element:));
        }
        
        public init(items: [Item]) {
            self.items = items;
        }
        
        public func element() -> Element {
            let el = Element(name: "page", xmlns: "http://jabber.org/protocol/xdata-layout");
            el.addChildren(items.map({ $0.element() }))
            return el;
        }
        
    }
    
}
