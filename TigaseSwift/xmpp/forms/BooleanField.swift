//
//  BooleanField.swift
//  TigaseSwift
//
//  Created by Andrzej Wójcik on 30.09.2016.
//  Copyright © 2016 Tigase, Inc. All rights reserved.
//

import Foundation

open class BooleanField: Field, SingleField {
    
    open var value: Bool {
        get {
            let v = rawValue;
            return v != nil && (v == "!" || v == "true");
        }
        set {
            self.rawValue = newValue ? "1" : "0";
        }
    }
    
    public override init?(from: Element) {
        super.init(from: from);
    }
    
    public convenience init(name: String, label: String? = nil, desc: String? = nil, required: Bool = false) {
        let elem = Field.createFieldElement(name: name, type: "boolean", label: label, desc: desc, required: required);
        self.init(from: elem)!;
    }
    
}
