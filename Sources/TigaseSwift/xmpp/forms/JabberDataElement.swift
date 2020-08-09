//
// JabberDataElement.swift
//
// TigaseSwift
// Copyright (C) 2016 "Tigase, Inc." <office@tigase.com>
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

open class JabberDataElementFieldAware {
    
    public let element: Element;
    
    open var fieldNames: [String] {
        var names = [String]();
        element.forEachChild(name: "field") { (fieldEl) in
            if let name = fieldEl.getAttribute("var") {
                names.append(name);
            }
        }
        return names;
    }
    
    public init?(from: Element) {
        self.element = from;
    }
    
    @discardableResult
    open func addField<T: Field>(_ field: T) -> T {
        element.removeChildren(where: { (elem)->Bool in return elem.name == "field" && elem.getAttribute("var") == field.name});
        element.addChild(field.element);
        return field;
    }
    
    open func getField<T: Field>(named name: String) -> T? {
        guard let fieldEl = element.findChild(where: { (elem)->Bool in return elem.name == "field" && elem.getAttribute("var") == name}) else {
            return nil;
        }
        
        return wrapIntoField(elem: fieldEl) as? T;
    }
    
    open func removeField(named name: String) {
        element.removeChildren(where: { (elem)->Bool in return elem.name == "field" && elem.getAttribute("var") == name})
    }
    
    open func removeField(_ field: Field) {
        element.removeChildren(where: { (elem)->Bool in return elem == field.element});
    }
    
    open func wrapIntoField(elem: Element) -> Field? {
        let type: String = elem.getAttribute("type") ?? "text-single";
        switch type {
        case "boolean":
            return BooleanField(from: elem);
        case "fixed":
            return FixedField(from: elem);
        case "hidden":
            return HiddenField(from: elem);
        case "jid-multi":
            return JidMultiField(from: elem);
        case "jid-single":
            return JidSingleField(from: elem);
        case "list-multi":
            return ListMultiField(from: elem);
        case "list-single":
            return ListSingleField(from: elem);
        case "text-multi":
            return TextMultiField(from: elem);
        case "text-private":
            return TextPrivateField(from: elem);
        default:
            return TextSingleField(from: elem);
        }
    }
    
}

open class JabberDataElement: JabberDataElementFieldAware {
    
    open var visibleFieldNames: [String] {
        var names = [String]();
        element.forEachChild(name: "field") { (fieldEl) in
            if fieldEl.getAttribute("type") != "hidden" {
                if let name = fieldEl.getAttribute("var") {
                    names.append(name);
                }
            }
        }
        return names;
    }
    
    open var instructions: [String?]? {
        get {
            let elems = element.getChildren(name: "instructions");
            guard !elems.isEmpty else {
                return nil;
            }
            return elems.map { (elem)-> String? in return elem.value };
        }
        set {
            element.getChildren(name: "instructions").forEach { (elem) in
                element.removeChild(elem);
            };
            
            newValue?.forEach { (v) in
                if v != nil {
                    element.addChild(Element(name: "instructions", cdata: v!));
                } else {
                    element.addChild(Element(name: "instructions"));
                }
            }
        }
    }

    open var reported: [Reported] {
        return element.mapChildren(transform: { (el)  in
            return Reported(from: el, parent: self.element);
        }) { (el) -> Bool in
            return el.name == "reported";
        }
    }
    
    open var title: String? {
        get {
            return element.findChild(name: "title")?.value;
        }
        set {
            let titleEl = element.findChild(name: "title");
            if newValue != nil {
                if titleEl != nil {
                    titleEl?.value = newValue;
                } else {
                    element.addChild(Element(name: "title", cdata: newValue));
                }
            } else if titleEl != nil {
                element.removeChild(titleEl!);
            }
        }
    }
    
    open var type: XDataType? {
        guard let typeStr = element.getAttribute("type") else {
            return nil;
        }
        return XDataType(rawValue: typeStr);
    }
    
    public convenience init(type: XDataType) {
        let elem = Element(name: "x", xmlns: "jabber:x:data");
        elem.setAttribute("type", value: type.rawValue);
        self.init(from: elem)!;
    }
    
    public override init?(from element: Element?) {
        guard element?.name == "x" && element?.xmlns == "jabber:x:data" else {
            return nil;
        }
        super.init(from: element!);
    }
    
    open func submitableElement(type: XDataType) -> Element {
        let elem = Element(element: self.element);
        elem.setAttribute("type", value: type.rawValue);
        return elem;
    }
    
}

open class Field {
    
    public let element: Element;
    
    open var name: String {
        return element.getAttribute("var")!;
    }
    open var type: String? {
        return element.getAttribute("type");
    }
    open var label: String? {
        get {
            return element.getAttribute("label");
        }
        set {
            element.setAttribute("label", value: newValue);
        }
    }
    open var desc: String? {
        get {
            return element.findChild(name: "desc")?.value;
        }
        set {
            let descEl = element.findChild(name: "desc");
            if newValue != nil {
                if descEl != nil {
                    descEl?.value = newValue;
                } else {
                    element.addChild(Element(name: "desc", cdata: newValue));
                }
            } else if descEl != nil {
                element.removeChild(descEl!);
            }
        }
    }
    open var required: Bool {
        get {
            return element.findChild(name: "required") != nil;
        }
        set {
            let elem = element.findChild(name: "required");
            if newValue && elem == nil {
                element.addChild(Element(name: "required"));
            } else if !newValue && elem != nil {
                element.removeChild(elem!);
            }
        }
    }
    
    open var media: [Media] {
        get {
            return element.mapChildren(transform: Media.init(from: ));
        }
    }
    
    public init?(from: Element) {
        guard from.name == "field" && from.getAttribute("var") != nil else {
            return nil;
        }
        self.element = from;
    }
    
    public static func createFieldElement(name: String, type: String?, label: String? = nil, desc: String? = nil, required: Bool = false) -> Element {
        let elem = Element(name: "field");
        elem.setAttribute("var", value: name);
        elem.setAttribute("type", value: type);
        elem.setAttribute("label", value: label);
        if desc != nil {
            elem.addChild(Element(name: "desc", cdata: desc));
        }
        if required {
            elem.addChild(Element(name: "required"));
        }
        return elem;
    }

    open class Media {
        public let element: Element;
        
        public var uris: [Uri] {
            get {
                return element.mapChildren(transform: Uri.init(from: ), filter: { $0.name == "uri" && $0.value != nil });
            }
        }
        
        public init?(from: Element) {
            guard from.name == "media" && from.xmlns == "urn:xmpp:media-element" else {
                return nil;
            }
            self.element = from;
        }
        
        open class Uri {
            public let element: Element;
            
            public var type: String;
            public var value: String;
            
            public init?(from el: Element) {
                guard el.name == "uri", let value = el.value, let type = el.getAttribute("type") else {
                    return nil;
                }
                self.element = el;
                self.type = type;
                self.value = value;
            }
        }
    }
}

open class Reported {
    public let element: Element;
    fileprivate let parent: Element;
    
    open var rows: [Row] {
        let children = parent.getChildren();
        var idx = children.firstIndex(of: element)!.advanced(by: 1);
        var result: [Row] = [];
        while children.count > idx && children[idx].name == "item" {
            if let row = Row(from: children[idx]) {
                result.append(row);
            }
            idx = idx.advanced(by: 1);
        }
        return result;
    };
    
    public init?(from: Element, parent: Element) {
        guard from.name == "reported" && parent.findChild(where: { el in el == from }) != nil else {
            return nil;
        }
        self.element = from;
        self.parent = parent;
    }
    
    open var fieldNames: [String] {
        return element.mapChildren(transform: { (fieldEl) in
            return fieldEl.getAttribute("var");
        }, filter: { (child) in child.name == "field" });
    }
    
    open var count: Int {
        let children = parent.getChildren();
        let start = children.firstIndex(of: element)!.advanced(by: 1);
        var end = start;
        while children.count > end && children[end].name == "item" {
            end = end.advanced(by: 1);
        }
        
        // FIXME: maybe it would be better to create rows when reported element is created??
        return end.distance(to: start);
    }
    
    open class Row: JabberDataElementFieldAware {
        
        public override init?(from: Element) {
            guard from.name == "item" else {
                return nil;
            }
            super.init(from: from);
        }
        
    }
}

public enum XDataType: String {
    case cancel
    case form
    case result
    case submit
}

public protocol ValidatableField {
    
    var valid: Bool { get }
    
}
