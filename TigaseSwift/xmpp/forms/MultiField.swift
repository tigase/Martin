//
//  MultiField.swift
//  TigaseSwift
//
//  Created by Andrzej Wójcik on 30.09.2016.
//  Copyright © 2016 Tigase, Inc. All rights reserved.
//

import Foundation

public protocol MultiField: class, ValidatableField {
    
    var element: Element { get }
    
    var rawValue: [String] { get set }
    
    var required: Bool { get set }
    
}

public extension MultiField {
    
    public var rawValue: [String] {
        get {
            return element.mapChildren(transform: { (elem) -> String in return elem.value!}, filter: { (elem) -> Bool in return elem.name == "value"});
        }
        set {
            element.removeChildren(where: { (elem) -> Bool in return elem.name == "value" });
            newValue.forEach { (v) in
                element.addChild(Element(name: "value", cdata: v));
            }
        }
    }
 
    public var valid: Bool {
        return (!self.required) || !rawValue.isEmpty;
    }
}
