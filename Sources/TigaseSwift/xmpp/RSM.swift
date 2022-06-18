//
// RSM.swift
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
import CoreMedia

public struct RSM {
    
    public static let XMLNS = "http://jabber.org/protocol/rsm";

    public enum Query {
        case after(String, max: Int?)
        case before(String, max: Int?)
        case between(String, String, max: Int?)
        case skipOffset(Int, max: Int?)
        case last(Int)
        case max(Int)
        
        public init?(_ el: Element) {
            guard el.name == "set" && el.xmlns == RSM.XMLNS else {
                return nil;
            }
            let maxStr = el.firstChild(name: "max")?.value;
            let max = maxStr != nil ? Int(maxStr!) : nil;
            let beforeEl = el.firstChild(name: "before");
            if let after = el.firstChild(name: "after")?.value {
                if let before = beforeEl?.value {
                    self = .between(after, before, max: max);
                } else {
                    self = .after(after, max: max);
                }
            } else if beforeEl != nil {
                if let before = beforeEl?.value {
                    self = .before(before, max: max);
                } else if let max = max {
                    self = .last(max)
                } else {
                    return nil;
                }
            } else if let indexStr = el.firstChild(name: "index")?.value, let index = Int(indexStr) {
                self = .skipOffset(index, max: max);
            } else if let max = max {
                self = .max(max);
            }
            return nil;
        }
        
        public func element() -> Element {
            let element = Element(name: "set", xmlns: RSM.XMLNS);
            switch self {
            case .after(let id, let max):
                element.addChild(Element(name: "after", cdata: id));
                if let max = max {
                    element.addChild(Element(name: "max", cdata: String(max)));
                }
            case .before(let id, let max):
                element.addChild(Element(name: "before", cdata: id));
                if let max = max {
                    element.addChild(Element(name: "max", cdata: String(max)));
                }
            case .between(let aid, let bid, let max):
                element.addChild(Element(name: "after", cdata: aid));
                element.addChild(Element(name: "before", cdata: bid));
                if let max = max {
                    element.addChild(Element(name: "max", cdata: String(max)));
                }
            case .skipOffset(let offset, let max):
                element.addChild(Element(name: "index", cdata: String(offset)));
                if let max = max {
                    element.addChild(Element(name: "max", cdata: String(max)));
                }
            case .last(let max):
                element.addChild(Element(name: "before"));
                element.addChild(Element(name: "max", cdata: String(max)));
            case .max(let max):
                element.addChild(Element(name: "max", cdata: String(max)));
            }
            return element;
        }
        
    }

    public struct Result {
        public let first: String?;
        public let last: String?;
        public let index: Int?;
        public let count: Int?;
        
        public init(first: String?, last: String?, index: Int?, count: Int?) {
            self.first = first;
            self.last = last;
            self.index = index;
            self.count = count;
        }
        
        public init?(from element: Element?) {
            guard let el = element else {
                return nil;
            }
            self.init(element: el);
        }
        
        public init?(element: Element) {
            guard element.name == "set" && element.xmlns == RSM.XMLNS else {
                return nil;
            }
            first = element.firstChild(name: "first")?.value;
            last = element.firstChild(name: "last")?.value;
            if let indexStr = element.firstChild(name: "first")?.attribute("index") {
                index = Int(indexStr);
            } else {
                index = nil;
            }
            if let countStr = element.firstChild(name: "count")?.value {
                count = Int(countStr);
            } else {
                count = nil;
            }
        }
        
        public func next(_ max: Int? = nil) -> RSM.Query? {
            if let last = last {
                return .after(last, max: max);
            }
            return nil;
        }
        
        public func previous(_ max: Int? = nil) -> RSM.Query? {
            if let first = first {
                return .before(first, max: max);
            }
            return nil;
        }
        
        public func element() -> Element? {
            let el = Element(name: "set", xmlns: RSM.XMLNS);
            if let first = first {
                let firstEl = Element(name: "first", cdata: first);
                if let index = index {
                    el.attribute("index", newValue: String(index));
                }
                el.addChild(firstEl)
            }
            if let last = last {
                el.addChild(Element(name: "last", cdata: last));
            }
            if let count = count {
                el.addChild(Element(name: "count", cdata: String(count)));
            }
            return el;
        }
    }
    
}
