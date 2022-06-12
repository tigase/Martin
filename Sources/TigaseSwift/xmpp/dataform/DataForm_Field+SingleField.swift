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
    
    open class SingleField<Value: Equatable>: DataForm.Field {

        private let origValue: Value;
        public var currentValue: Value;
        
        public override var wasModified: Bool {
            return origValue != currentValue;
        }
        
        public init(`var`: String, type: FieldType? = .textSingle, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: Value, originalValue: Value) {
            self.origValue = originalValue;
            self.currentValue = value;
            super.init(var: `var`, type: type, required: required, label: label, desc: desc, media: media);
        }
        
        public init?(element el: Element, value: Value) {
            self.origValue = value;
            self.currentValue = value;
            super.init(element: el);
        }
    }
    
    open class TextSingle: SingleField<String?> {
        
        open override var isValid: Bool {
            return !isRequired || currentValue != nil;
        }

        public required init?(element el: Element) {
            super.init(element: el, value: el.findChild(name: "value")?.value);
        }

        public init(`var`: String, type: FieldType? = .textSingle, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: String? = nil) {
            super.init(var: `var`, type: type, required: required, label: label, desc: desc, media: media, value: value, originalValue: nil);
        }
        
        open func value<V: LosslessStringConvertible>() -> V? {
            guard let val = currentValue else {
                return nil;
            }
            return V(val);
        }
        
        open func value<V: LosslessStringConvertible>(_ value: V?) {
            currentValue = value?.description;
        }
        
        open override func element(formType: DataForm.FormType) -> Element {
            let el = super.element(formType: formType);
            if let value = currentValue {
                el.addChild(Element(name: "value", cdata: value));
            }
            return el;
        }

    }
    
    open class JIDSingle: SingleField<JID?> {
        
        open override var isValid: Bool {
            return !isRequired || currentValue != nil;
        }

        public required init?(element el: Element) {
            super.init(element: el, value: JID(el.findChild(name: "value")?.value));
        }

        public init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: JID? = nil) {
            super.init(var: `var`, type: .jidSingle, required: required, label: label, desc: desc, media: media, value: value, originalValue: nil);
        }
        
        open func value() -> JID? {
            return currentValue;
        }
        
        open func value(_ value: JID?) {
            self.currentValue = value;
        }

        open override func element(formType: DataForm.FormType) -> Element {
            let el = super.element(formType: formType);
            if let value = currentValue?.stringValue {
                el.addChild(Element(name: "value", cdata: value));
            }
            return el;
        }

    }
    
    open class Boolean: SingleField<Bool> {

        public required init?(element el: Element) {
            let val = el.findChild(name: "value")?.value;
            super.init(element: el, value: "1" == val || "true" == val);
        }

        public init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: Bool = false) {
            super.init(var: `var`, type: .boolean, required: required, label: label, desc: desc, media: media, value: value, originalValue: false);
        }
        
        open func value() -> Bool {
            return currentValue;
        }
        
        open func value(_ value: Bool) {
            self.currentValue = currentValue;
        }
        
        open override func element(formType: DataForm.FormType) -> Element {
            let el = super.element(formType: formType);
            el.addChild(Element(name: "value", cdata: currentValue ? "true" : "false"));
            return el;
        }

    }
    
    open class TextPrivate: TextSingle {
        
        open override var isValid: Bool {
            return !isRequired || currentValue != nil;
        }
        
        public required init?(element: Element) {
            super.init(element: element);
        }
        
        public init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: String? = nil) {
            super.init(var: `var`, type: .textPrivate, required: required, label: label, desc: desc, media: media, value: value);
        }
    }

    open class Hidden: TextSingle {
        
        public required init?(element: Element) {
            super.init(element: element);
        }
        
        public init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: String? = nil) {
            super.init(var: `var`, type: .hidden, required: required, label: label, desc: desc, media: media, value: value);
        }
    }

    open class Fixed: TextSingle {
        
        public required init?(element: Element) {
            super.init(element: element);
        }
        
        public init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], value: String? = nil) {
            super.init(var: `var`, type: .fixed, required: required, label: label, desc: desc, media: media, value: value);
        }
    }
    
    open class ListSingle: TextSingle {
        public let options: [Option];
        
        open override var isValid: Bool {
            return !isRequired || currentValue != nil;
        }

        public required init?(element el: Element) {
            options = Option.from(element: el);
            super.init(element: el);
        }
        
        public init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], options: [Option] = [], value: String? = nil) {
            self.options = options;
            super.init(var: `var`, type: .listSingle, required: required, label: label, desc: desc, media: media, value: value);
        }
    }
    
}
