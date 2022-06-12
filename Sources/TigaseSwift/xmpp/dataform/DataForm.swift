//
// DataForm.swift
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

open class DataForm: DataFormProtocol {

    public enum FormType: String {
        case cancel
        case form
        case result
        case submit
    }

    open class Field {
        
        public enum FieldType: String {
            case boolean
            case fixed
            case hidden
            case jidMulti = "jid-multi"
            case jidSingle = "jid-single"
            case listMulti = "list-multi"
            case listSingle = "list-single"
            case textMulti = "text-multi"
            case textPrivate = "text-private"
            case textSingle = "text-single"

            public init?(string: String?) {
                guard let val = string else {
                    return nil;
                }
                self.init(rawValue: val);
            }
        }
        
        public struct Media {

            public static func from(element el: Element) -> [Media] {
                return el.mapChildren(transform: Media.init(element:));
            }

            public let uris: [Uri];

            public init?(element el: Element) {
                guard el.name == "media" && el.xmlns == "urn:xmpp:media-element" else {
                    return nil;
                }
                uris = el.getChildren(name: "uri").compactMap(Uri.init(element:));
            }

            public init(uris: [Uri]) {
                self.uris = uris;
            }

            public struct Uri {
                public let type: String;
                public let value: String;

                public init(type: String, value: String) {
                    self.type = type;
                    self.value = value;
                }

                public init?(element el: Element) {
                    guard el.name == "uri", let type = el.getAttribute("type"), let value = el.value else {
                        return nil;
                    }
                    self.init(type: type, value: value);
                }
            }
        }
        
        public struct Option {
            
            public static func from(element el: Element) -> [Option] {
                return el.mapChildren(transform: Option.init(element:));
            }
            
            public let label: String?;
            public let value: String;
            
            public init(value: String, label: String? = nil) {
                self.value = value;
                self.label = label;
            }
            
            public init?(element el: Element) {
                guard el.name == "option", let value = el.findChild(name: "value")?.value else {
                    return nil;
                }
                self.init(value: value, label: el.getAttribute("label"));
            }
        }

        
        public static func parse(element el: Element) -> Field? {
            guard el.name == "field" else {
                return nil;
            }
            
            let type = Field.FieldType(string: el.getAttribute("type")) ?? .textSingle;
            switch type {
            case .boolean:
                return .Boolean(element: el);
            case .fixed:
                return .Fixed(element: el);
            case .hidden:
                return .Hidden(element: el);
            case .jidMulti:
                return .JIDMulti(element: el);
            case .jidSingle:
                return .JIDSingle(element: el);
            case .listMulti:
                return .ListMulti(element: el);
            case .listSingle:
                return .ListSingle(element: el);
            case .textMulti:
                return .TextMulti(element: el);
            case .textPrivate:
                return .TextPrivate(element: el);
            case .textSingle:
                return .TextSingle(element: el);
            }
        }
        
        public let `var`: String;
        public let type: FieldType?;
        public let isRequired: Bool;
        public let label: String?;
        public let desc: String?;
        public let media: [Media];

        open var wasModified: Bool {
            return false;
        }
        
        open var shouldSubmit: Bool {
            return self.isRequired || self.wasModified || self.type == .hidden;
        }
        
        open var isValid: Bool {
            return true;
        }
        
        public init?(element el: Element) {
            guard let v = el.getAttribute("var") else {
                return nil;
            }

            self.var = v;
            self.type = FieldType(string: el.getAttribute("type"));
            self.isRequired = el.hasChild(name: "required");
            self.label = el.getAttribute("label");
            self.desc = el.findChild(name: "desc")?.value;
            self.media = Media.from(element: el);
        }
        
        public init(`var`: String, type: FieldType? = nil, required: Bool = false, label: String? = nil, desc: String?, media: [Media] = []) {
            self.var = `var`;
            self.type = type;
            self.isRequired = required;
            self.label = label;
            self.desc = desc;
            self.media = media;
        }
        
        open func element(formType: FormType) -> Element {
            let elem = Element(name: "field");
            elem.setAttribute("var", value: self.var);
            elem.setAttribute("type", value: type?.rawValue);
            if formType != .submit {
                elem.setAttribute("label", value: label);
                if desc != nil {
                    elem.addChild(Element(name: "desc", cdata: desc));
                }
                if isRequired {
                    elem.addChild(Element(name: "required"));
                }
            }
            return elem;
        }

    }
        
    public let type: FormType;
    open var title: String?;
    open var instructions: [String];
    open private(set) var fields: [Field];
    open var reported: [Reported];
    open var layout: [Page];

    public convenience init?(element: Element?) {
        guard let el = element else {
            return nil;
        }
        self.init(element: el);
    }
    
    public convenience init?(element form: Element) {
        guard form.name == "x" && form.xmlns == "jabber:x:data" else {
            return nil;
        }

        guard let typeStr = form.getAttribute("type"), let type = FormType(rawValue: typeStr) else {
            return nil;
        }

        self.init(type: type, title: form.findChild(name: "title")?.value, instructions: form.getChildren(name: "instructions").map({ $0.value ?? "" }), fields: form.getChildren(name: "field").compactMap(Field.parse(element:)), reported: Reported.from(formElement: form), layout: form.getChildren(name: "page", xmlns: "http://jabber.org/protocol/xdata-layout").compactMap(Page.init(element:)));
    }

    public init(type: FormType, title: String? = nil, instructions: [String] = [], fields: [Field] = [], reported: [Reported] = [], layout: [Page] = []) {
        self.type = type;
        self.title = title;
        self.instructions = instructions;
        self.fields = fields;
        self.reported = reported;
        self.layout = layout;
    }
                                      
    open func add(field: Field) {
        self.remove(field: field);
        self.fields.append(field);
    }
    
    open func remove(field: Field) {
        self.fields.removeAll(where: { $0.var == field.var });
    }
    
    open func field(for `var`: String) -> Field? {
        return fields.first(where: { $0.var == `var`});
    }
    
    open func field<F: Field>(for `var`: String) -> F? {
        return fields.first(where: { $0.var == `var`}) as? F;
    }
    
    open func field<F: Field>(for `var`: String, type: F.Type) -> F? {
        return field(for: `var`);
    }
    
    open func value<V: LosslessStringConvertible>(for key: String, type: V.Type) -> V? {
        guard let field = fields.first(where: { $0.var == key }) else {
            return nil;
        }
        switch field {
        case let jidSingleField as Field.JIDSingle:
            guard let value = jidSingleField.currentValue else {
                return nil;
            }
            if type is JID.Type {
                return value as? V;
            } else {
                return type.init(value.description);
            }
        case let textSingleField as Field.TextSingle:
            guard let value = textSingleField.currentValue else {
                return nil;
            }
            if type is String.Type {
                return value as? V;
            } else {
                return type.init(value);
            }
        case let fixedField as Field.Fixed:
            guard let value = fixedField.currentValue else {
                return nil;
            }
            if type is String.Type {
                return value as? V;
            } else {
                return type.init(value);
            }
        case let booleanField as Field.Boolean:
            switch type {
            case is Bool.Type:
                return booleanField.currentValue as? V;
            case is String.Type:
                return booleanField.currentValue.description as? V;
            default:
                return nil;
            }
        default:
            return nil;
        }
    }
    
    open func value(for key: String, type: [String].Type) -> [String]? {
        guard let field = fields.first(where: { $0.var == key }) else {
            return nil;
        }
        switch field {
        case let textMultiField as Field.TextMulti:
            return textMultiField.currentValues;
        case let jidMultiField as Field.JIDMulti:
            return jidMultiField.currentValues.map({ $0.description });
        default:
            return nil;
        }
    }
    
    open func value(for key: String, type: [JID].Type) -> [JID]? {
        guard let field = fields.first(where: { $0.var == key })else {
            return nil;
        }
        switch field {
        case let textMultiField as Field.TextMulti:
            return textMultiField.currentValues.compactMap({ JID($0) });
        case let jidMultiField as Field.JIDMulti:
            return jidMultiField.currentValues;
        default:
            return nil;
        }
    }
        
    open func hasField(for key: String) -> Bool {
        return fields.contains(where: { $0.var == key });
    }
    
    open func fieldType(for key: String) -> Field.FieldType? {
        return fields.first(where: { $0.var == key })?.type;
    }
    
    open func element(type: FormType, onlyModified: Bool) -> Element {
        let elem = Element(name: "x", xmlns: "jabber:x:data");
        elem.setAttribute("type", value: type.rawValue);
        let fields = onlyModified ? self.fields.filter({ $0.shouldSubmit }) : self.fields;
        for field in fields {
            elem.addChild(field.element(formType: type));
        }
        return elem;
    }
    
    open func copyValues(from source: DataForm) {
        for newField in fields {
            if let oldField = source.field(for: newField.var) {
                switch newField {
                case let f as Field.JIDSingle:
                    f.currentValue = (oldField as? Field.JIDSingle)?.currentValue;
                case let f as Field.TextSingle:
                    f.currentValue = (oldField as? Field.TextSingle)?.currentValue;
                case let nf as Field.Boolean:
                    if let of = oldField as? Field.Boolean {
                        nf.currentValue = of.currentValue;
                    }
                case let nf as Field.JIDMulti:
                    if let of = oldField as? Field.JIDMulti {
                        nf.currentValues = of.currentValues;
                    }
                case let nf as Field.TextMulti:
                    if let of = oldField as? Field.TextMulti {
                        nf.currentValues = of.currentValues;
                    }
                default:
                    break;
                }
            }
        }
    }
}

public protocol DataFormProtocol {
    
    var fields: [DataForm.Field] { get }
    
    func hasField(for key: String) -> Bool
    
    func field(for key: String) -> DataForm.Field?
    func field<F: DataForm.Field>(for key: String) -> F?
    
    func add(field: DataForm.Field)
    func remove(field: DataForm.Field)
 
    func value<V: LosslessStringConvertible>(for key: String, type: V.Type) -> V?
    func value(for key: String, type: [String].Type) -> [String]?
    func value(for key: String, type: [JID].Type) -> [JID]?
    
    func element(type: DataForm.FormType, onlyModified: Bool) -> Element
}
