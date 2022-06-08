//
// DataForm_Field+MultiField.swift
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
    
    class MultiField<Value: Equatable>: DataForm.Field {
        private let origValues: [Value];
        public var currentValues: [Value];

        public override var wasModified: Bool {
            return origValues != currentValues;
        }
        
        init(`var`: String, type: FieldType? = .textMulti, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], values: [Value] = []) {
            self.origValues = [];
            self.currentValues = values;
            super.init(var: `var`, type: type, required: required, label: label, desc: desc, media: media);
        }

        init?(element el: Element, values: [Value]) {
            origValues = values;
            currentValues = values;
            super.init(element: el);
        }

    }

    class TextMulti: MultiField<String> {

        required init?(element el: Element) {
            super.init(element: el, values: el.getChildren(name: "value").compactMap({ $0.value }));
        }
        
        override init(`var`: String, type: FieldType? = .textMulti, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], values: [String] = []) {
            super.init(var: `var`, type: type, required: required, label: label, desc: desc, media: media, values: values);
        }
        
        func values<K: LosslessStringConvertible>() -> [K] {
            return currentValues.compactMap({ K($0) });
        }
        
        func values<K: LosslessStringConvertible>(_ values: [K]) {
            currentValues = values.map({ $0.description })
        }

        override func element(formType: DataForm.FormType) -> Element {
            let el = super.element(formType: formType);
            for value in currentValues {
                el.addChild(Element(name: "value", cdata: value));
            }
            return el;
        }

    }
    
    class JIDMulti: MultiField<JID> {
        
        required init?(element el: Element) {
            super.init(element: el, values: el.getChildren(name: "value").compactMap({ $0.value }).compactMap({ JID( $0 )}));
        }
        
        override init(`var`: String, type: FieldType? = .jidMulti, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], values: [JID] = []) {
            super.init(var: `var`, type: type, required: required, label: label, desc: desc, media: media, values: values);
        }
        
        func values() -> [JID] {
            return currentValues;
        }
        
        func values(_ values: [JID]) {
            currentValues = values;
        }

        override func element(formType: DataForm.FormType) -> Element {
            let el = super.element(formType: formType);
            for value in currentValues {
                el.addChild(Element(name: "value", cdata: value.stringValue));
            }
            return el;
        }
    }

    class ListMulti: TextMulti {
        let options: [Option];
        
        required init?(element el: Element) {
            options = Option.from(element: el);
            super.init(element: el);
        }

        init(`var`: String, required: Bool = false, label: String? = nil, desc: String? = nil, media: [Media] = [], options: [Option] = [], values: [String] = []) {
            self.options = options;
            super.init(var: `var`, type: .listMulti, required: required, label: label, desc: desc, media: media, values: values);
        }
    }

}
