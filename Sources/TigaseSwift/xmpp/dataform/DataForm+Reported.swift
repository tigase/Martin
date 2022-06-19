//
// DataForm+Reported.swift
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
    
    public struct Reported {
        
        public static func from(formElement: Element) -> [Reported] {
            return formElement.filterChildren(name: "reported").compactMap({ Reported(element: $0, formElement: formElement) });
        }
        
        public let fields: [Field];
        public let items: [Item];
        
        public init?(element el: Element, formElement: Element) {
            guard el.name == "reported", formElement.name == "x" && formElement.xmlns == "jabber:x:data" else {
                return nil;
            }
            
            let fields = el.compactMapChildren(Field.parse(element:));
            self.fields = fields;
            
            var children = formElement.children.drop(while: { $0 !== el }).dropFirst();
            if let endIdx = children.firstIndex(where: { $0.name == "reported" }) {
                children = children[0..<endIdx];
            }
            items = children.compactMap({ Item(element: $0)});
        }
        
        public init(fields: [Field], items: [Item]) {
            self.fields = fields;
            self.items = items;
        }
    
        public func elements() -> [Element] {
            let el = Element(name: "reported");
            el.addChildren(fields.map({ $0.element(formType: .result) }));
            
            return [el] + items.map({ $0.element() });
        }
        
        public struct Item {
            public let fields: [FieldValue];
            
            public init?(element: Element) {
                fields = element.filterChildren(name: "field").compactMap(FieldValue.init(element:));
            }
            
            public init(fields: [FieldValue]) {
                self.fields = fields;
            }
            
            public func element() -> Element {
                let el = Element(name: "item");
                el.addChildren(fields.map({ $0.element() }))
                return el;
            }
            
            public struct FieldValue {
                public let `var`: String;
                public let values: [String];
                
                public init?(element el: Element) {
                    guard let `var` = el.attribute("var") else {
                        return nil;
                    }
                    self.var = `var`;
                    self.values = el.filterChildren(name: "value").compactMap({ $0.value });
                }
                
                public init(`var`: String, values: [String]) {
                    self.var = `var`;
                    self.values = values;
                }
                
                public func element() -> Element {
                    let el = Element(name: "field");
                    el.attribute("var", newValue: self.var);
                    el.addChildren(values.map({ Element(name: "value", cdata: $0) }));
                    return el;
                }
            }
        }
    }
    
}
