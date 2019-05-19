//
// MultiField.swift
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

public protocol MultiField: class, ValidatableField {
    
    var element: Element { get }
    
    var rawValue: [String] { get set }
    
    var required: Bool { get set }
    
}

public extension MultiField {
    
    var rawValue: [String] {
        get {
            return element.mapChildren(transform: { (elem) -> String in return elem.value!}, filter: { (elem) -> Bool in return elem.name == "value" && elem.value != nil});
        }
        set {
            element.removeChildren(where: { (elem) -> Bool in return elem.name == "value" });
            newValue.forEach { (v) in
                element.addChild(Element(name: "value", cdata: v));
            }
        }
    }
 
    var valid: Bool {
        return (!self.required) || !rawValue.isEmpty;
    }
}
