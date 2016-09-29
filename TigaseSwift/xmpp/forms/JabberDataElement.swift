//
//  JabberDataElement.swift
//  TigaseSwift
//
//  Created by Andrzej Wójcik on 30.09.2016.
//  Copyright © 2016 Tigase, Inc. All rights reserved.
//

import Foundation

open class JabberDataElement {
    
    open let element: Element;
    
    open var fieldNames: [String] {
        var names = [String]();
        element.forEachChild(name: "field") { (fieldEl) in
            if let name = fieldEl.getAttribute("var") {
                names.append(name);
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
    
    public init?(from element: Element) {
        guard element.name == "x" && element.xmlns == "jabber:x:data" else {
            return nil;
        }
        self.element = element;
    }
    
    open func addField(_ field: Field) {
        element.removeChildren(where: { (elem)->Bool in return elem.name == "field" && elem.getAttribute("var") == field.name});
        element.addChild(field.element);
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
        switch element.getAttribute("type") ?? "text-single" {
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
            case "text-privete":
                return TextPrivateField(from: elem);
            default:
                return TextSingleField(from: elem);
        }
    }
    
    open func submitableElement(type: XDataType) -> Element {
        let elem = Element(element: self.element);
        elem.setAttribute("type", value: type.rawValue);
        return elem;
    }
}

open class Field {
    
    open let element: Element;
    
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
    
    public init?(from: Element) {
        guard from.name == "field" && from.getAttribute("var") != nil else {
            return nil;
        }
        self.element = from;
    }
    
    open static func createFieldElement(name: String, type: String?, label: String? = nil, desc: String? = nil, required: Bool = false) -> Element {
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
}

public enum XDataType: String {
    case cancel
    case form
    case result
    case submit
}
