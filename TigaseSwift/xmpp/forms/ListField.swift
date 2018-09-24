//
// ListField.swift
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

public protocol ListField: class {
    
    var element: Element { get }
    
}

public extension ListField {
    
    var options: [ListFieldOption] {
        get {
            return element.mapChildren(transform: { (elem) -> ListFieldOption in
                return ListFieldOption(value: elem.findChild(name: "value")?.value ?? "", label: elem.getAttribute("label"));
                }, filter: { (elem) -> Bool in
                    return elem.name == "option";
            });
        }
        set {
            element.removeChildren(where: { (elem) -> Bool in elem.name == "option"});
            newValue.forEach { (option) in
                let optionEl = Element(name: "option");
                optionEl.setAttribute("label", value: option.label);
                optionEl.addChild(Element(name: "value", cdata: option.value));
                element.addNode(optionEl);
            }
        }
    }
    
}

open class ListFieldOption {
    public let label: String?;
    public let value: String;
    
    public init(value: String, label: String? = nil) {
        self.value = value;
        self.label = label;
    }
}
