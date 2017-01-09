//
//  TextFieldSingle.swift
//  TigaseSwift
//
//  Created by Andrzej Wójcik on 30.09.2016.
//  Copyright © 2016 Tigase, Inc. All rights reserved.
//

import Foundation

open class TextSingleField: Field, SingleField {

    open var value: String? {
        get {
            return rawValue
        }
        set {
            self.rawValue = newValue;
        }
    }
    
    public override init?(from: Element) {
        super.init(from: from);
    }
    
    public convenience init(name: String, label: String? = nil, desc: String? = nil, required: Bool = false, value: String? = nil) {
        let elem = Field.createFieldElement(name: name, type: "text-single", label: label, desc: desc, required: required);
        self.init(from: elem)!;
        if (value != nil) {
            self.value = value;
        }
    }
    
}
