//
// DataForm_Field+SingleField.swift
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

extension DataForm.Field {
    
    class SingleField<Value: Equatable>: DataForm.Field {

        private let origValue: Value;
        public var currentValue: Value;
        
        public override var wasModified: Bool {
            return origValue != currentValue;
        }

        init(`var`: String, type: FieldType? = .textSingle, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: Value, originalValue: Value) {
            self.origValue = originalValue;
            self.currentValue = value;
            super.init(var: `var`, type: type, required: required, label: label, desc: desc, media: media);
        }
        
        init?(element el: Element, value: Value) {
            self.origValue = value;
            self.currentValue = value;
            super.init(element: el);
        }
    }
    
    class TextSingle: SingleField<String?> {
        
        required init?(element el: Element) {
            super.init(element: el, value: el.findChild(name: "value")?.value);
        }

        init(`var`: String, type: FieldType? = .textSingle, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: String? = nil) {
            super.init(var: `var`, type: type, required: required, label: label, desc: desc, media: media, value: value, originalValue: nil);
        }
        
        func value<V: LosslessStringConvertible>() -> V? {
            guard let val = currentValue else {
                return nil;
            }
            return V(val);
        }
        
        func value<V: LosslessStringConvertible>(_ value: V?) {
            currentValue = value?.description;
        }
        
        override func element(formType: DataForm.FormType) -> Element {
            let el = super.element(formType: formType);
            if let value = currentValue {
                el.addChild(Element(name: "value", cdata: value));
            }
            return el;
        }

    }
    
    class JIDSingle: SingleField<JID?> {
        
        required init?(element el: Element) {
            super.init(element: el, value: JID(el.findChild(name: "value")?.value));
        }

        init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: JID? = nil) {
            super.init(var: `var`, type: .jidSingle, required: required, label: label, desc: desc, media: media, value: value, originalValue: nil);
        }
        
        func value() -> JID? {
            return currentValue;
        }
        
        func value(_ value: JID?) {
            self.currentValue = value;
        }

        override func element(formType: DataForm.FormType) -> Element {
            let el = super.element(formType: formType);
            if let value = currentValue?.stringValue {
                el.addChild(Element(name: "value", cdata: value));
            }
            return el;
        }

    }
    
    class Boolean: SingleField<Bool> {

        required init?(element el: Element) {
            let val = el.findChild(name: "value")?.value;
            super.init(element: el, value: "1" == val || "true" == val);
        }

        init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: Bool = false) {
            super.init(var: `var`, type: .boolean, required: required, label: label, desc: desc, media: media, value: value, originalValue: false);
        }
        
        func value() -> Bool {
            return currentValue;
        }
        
        func value(_ value: Bool) {
            self.currentValue = currentValue;
        }
        
        override func element(formType: DataForm.FormType) -> Element {
            let el = super.element(formType: formType);
            el.addChild(Element(name: "value", cdata: currentValue ? "true" : "false"));
            return el;
        }

    }
    
    class TextPrivate: TextSingle {
        
        required init?(element: Element) {
            super.init(element: element);
        }
        
        init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: String? = nil) {
            super.init(var: `var`, type: .textPrivate, required: required, label: label, desc: desc, media: media, value: value);
        }
    }

    class Hidden: TextSingle {
        
        required init?(element: Element) {
            super.init(element: element);
        }
        
        init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: String? = nil) {
            super.init(var: `var`, type: .hidden, required: required, label: label, desc: desc, media: media, value: value);
        }
    }

    class Fixed: TextSingle {
        
        required init?(element: Element) {
            super.init(element: element);
        }
        
        init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: String? = nil) {
            super.init(var: `var`, type: .fixed, required: required, label: label, desc: desc, media: media, value: value);
        }
    }
    
    class ListSingle: TextSingle {
        let options: [Option];

        required init?(element el: Element) {
            options = Option.from(element: el);
            super.init(element: el);
        }
        
        init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], options: [Option] = [], value: String? = nil) {
            self.options = options;
            super.init(var: `var`, type: .listSingle, required: required, label: label, desc: desc, media: media, value: value);
        }
    }
    
}
