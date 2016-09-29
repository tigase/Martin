//
//  SingleField.swift
//  TigaseSwift
//
//  Created by Andrzej Wójcik on 30.09.2016.
//  Copyright © 2016 Tigase, Inc. All rights reserved.
//

import Foundation

public protocol SingleField: class {
    
    var element: Element { get }
    
    var rawValue: String? { get set }
    
}

extension SingleField {
    
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
        
}
