//
//  ListField.swift
//  TigaseSwift
//
//  Created by Andrzej Wójcik on 30.09.2016.
//  Copyright © 2016 Tigase, Inc. All rights reserved.
//

import Foundation

public protocol ListField: class {
    
    var element: Element { get }
    
}

public extension ListField {
    
    var options: [ListFieldOption] {
        get {
            return element.mapChildren(transform: { (elem) -> ListFieldOption in
                return ListFieldOption(value: elem.findChild(name: "value")!.value!, label: elem.getAttribute("label"));
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
    open let label: String?;
    open let value: String;
    
    public init(value: String, label: String? = nil) {
        self.value = value;
        self.label = label;
    }
}
