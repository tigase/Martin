//
// SingleField.swift
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

public protocol SingleField: class, ValidatableField {
    
    var element: Element { get }
    
    var rawValue: String? { get set }
    
    var required: Bool { get set }

}

public extension SingleField {
    
    public var rawValue: String? {
        get {
            return element.findChild(name: "value")?.value;
        }
        set {
            let v = element.findChild(name: "value");
            if newValue != nil {
                if v != nil {
                    v?.value = newValue;
                } else {
                    element.addChild(Element(name: "value", cdata: newValue));
                }
            } else if v != nil {
                element.removeChild(v!);
            }
        }
    }
    
    public var valid: Bool {
        return (!self.required) || rawValue != nil;
    }
}
