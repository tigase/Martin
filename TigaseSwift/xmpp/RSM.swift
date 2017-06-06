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


open class RSM {
    
    open static let XMLNS = "http://jabber.org/protocol/rsm";
    
    open class Query {
        
        let element: Element;
        
        var after: String? {
            return element.findChild(name: "after")?.value;
        }
        
        var before: String? {
            return element.findChild(name: "before")?.value;
        }
        
        var index: Int? {
            guard let v = element.findChild(name: "index")?.value else {
                return nil;
            }
            return Int(v);
        }
        
        var max: Int? {
            guard let v = element.findChild(name: "max")?.value else {
                return nil;
            }
            return Int(v);
        }
        
        init() {
            element = Element(name: "set", xmlns: RSM.XMLNS);
        }
        
        public convenience init(before: String? = nil, after: String? = nil, max: Int? = nil) {
            self.init();
            if max != nil {
                element.addChild(Element(name: "max", cdata: String(max!)));
            }
            if before != nil {
                element.addChild(Element(name: "before", cdata: before!));
            }
            if after != nil {
                element.addChild(Element(name: "after", cdata: after!));
            }
        }
        
        public convenience init(lastItems: Int) {
            self.init();
            element.addChild(Element(name: "max", cdata: String(lastItems)));
            element.addChild(Element(name: "before"));
        }
        
        public convenience init(from: Int, max: Int?) {
            self.init();
            if max != nil {
                element.addChild(Element(name: "max", cdata: String(max!)));
            }
            
            element.addChild(Element(name: "index", cdata: String(from)));
        }
        
        func setValue(_ name: String, value: String?) {
            if let elem = element.findChild(name: name) {
                if value != nil {
                    elem.value = value;
                } else {
                    element.removeChild(elem);
                }
            } else if value != nil {
                element.addChild(Element(name: name, cdata: value!));
            }
        }
        
    }
    
    open class Result {
        
        let element: Element;
        
        var first: String? {
            return element.findChild(name: "first")?.value;
        }
        
        var last: String? {
            return element.findChild(name: "last")?.value;
        }
        
        var index: Int? {
            guard let v = element.findChild(name: "first")?.getAttribute("index") else {
                return nil;
            }
            return Int(v);
        }
        
        var count: Int? {
            guard let v = element.findChild(name: "count")?.value else {
                return nil;
            }
            return Int(v);
        }
        
        public init?(from: Element?) {
            guard from?.name == "set" && from?.xmlns == RSM.XMLNS else {
                return nil;
            }
            
            self.element = from!;
        }
        
        public func next(_ max: Int? = nil) -> RSM.Query? {
            if let last = self.last {
                return RSM.Query(after: last, max: max);
            }
            return nil;
        }
        
        public func previous(_ max: Int? = nil) -> RSM.Query? {
            if let first = self.first {
                return RSM.Query(before: first, max: max);
            }
            return nil;
        }
        
        func setValue(_ name: String, value: String?) {
            if let elem = element.findChild(name: name) {
                if value != nil {
                    elem.value = value;
                } else {
                    element.removeChild(elem);
                }
            } else if value != nil {
                element.addChild(Element(name: name, cdata: value!));
            }
        }
    }
}
