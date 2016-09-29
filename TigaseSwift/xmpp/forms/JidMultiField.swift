//
//  JidMultiField.swift
//  TigaseSwift
//
//  Created by Andrzej Wójcik on 30.09.2016.
//  Copyright © 2016 Tigase, Inc. All rights reserved.
//

import Foundation

open class JidMultiField: Field, MultiField {
    
    open var value: [JID] {
        get {
            return rawValue.map({ str -> JID in return JID(str) });
        }
        set {
            self.rawValue = newValue.map({ jid -> String in return jid.stringValue });
        }
    }
    
    public override init?(from: Element) {
        super.init(from: from);
    }
    
    public convenience init(name: String, label: String? = nil, desc: String? = nil, required: Bool = false) {
        let elem = Field.createFieldElement(name: name, type: "jid-multi", label: label, desc: desc, required: required);
        self.init(from: elem)!;
    }
}
