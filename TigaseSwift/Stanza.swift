//
// Stanza.swift
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

public class Stanza: ElementProtocol, CustomStringConvertible {
    
    private let defStanzaType:StanzaType?;
    
    public var description: String {
        return String("Stanza : \(element.stringValue)")
    }
    
    public let element:Element;
    
    public var name:String {
        get {
            return element.name;
        }
    }
    
    public var from:JID? {
        get {
            if let jidStr = element.getAttribute("from") {
                return JID(jidStr);
            }
            return nil;
        }
        set {
            element.setAttribute("from", value: newValue?.stringValue);
        }
    }
    
    public var to:JID? {
        get {
            if let jidStr = element.getAttribute("to") {
                return JID(jidStr);
            }
            return nil;
        }
        set {
            element.setAttribute("to", value:newValue?.stringValue);
        }
    }
    
    public var id:String? {
        get {
            return element.getAttribute("id");
        }
        set {
            element.setAttribute("id", value: newValue);
        }
    }
    
    public var type:StanzaType? {
        get {
            if let type = element.getAttribute("type") {
                return StanzaType(rawValue: type);
            }
            return defStanzaType;
        }
        set {
            element.setAttribute("type", value: (newValue == defStanzaType) ? nil : newValue?.rawValue);
        }
    }
    
    public var errorCondition:ErrorCondition? {
        get {
            if type != StanzaType.error {
                return nil;
            }
            if let name = element.findChild("error")?.findChild(xmlns:"urn:ietf:params:xml:ns:xmpp-stanzas")?.name {
                return ErrorCondition(rawValue: name);
            }
            return nil;
        }
    }

    public var xmlns:String? {
        get {
            return element.xmlns;
        }
    }
    
    init(name:String, defStanzaType:StanzaType? = nil) {
        self.element = Element(name: name);
        self.defStanzaType = defStanzaType;
    }
    
    init(elem:Element, defStanzaType:StanzaType? = nil) {
        self.element = elem;
        self.defStanzaType = defStanzaType;
    }
    
    public func addChild(child: Element) {
        self.element.addNode(child)
    }
    
    public func addChildren(children: [Element]) {
        self.element.addChildren(children);
    }
    
    public func findChild(name:String? = nil, xmlns:String? = nil) -> Element? {
        return self.element.findChild(name, xmlns: xmlns);
    }
    
    public func getChildren(name:String? = nil, xmlns:String? = nil) -> Array<Element> {
        return self.element.getChildren(name, xmlns: xmlns);
    }
    
    public func getAttribute(key:String) -> String? {
        return self.element.getAttribute(key);
    }
    
    public func removeChild(child: Element) {
        self.element.removeChild(child);
    }
    
    public func setAttribute(key:String, value:String?) {
        self.element.setAttribute(key, value: value);
    }
    
    public static func fromElement(elem:Element) -> Stanza {
        switch elem.name {
        case "message":
            return Message(elem:elem);
        case "presence":
            return Presence(elem:elem);
        case "iq":
            return Iq(elem:elem);
        default:
            return Stanza(elem:elem);
        }
    }
    
    public func errorResult(condition:ErrorCondition, text:String? = nil) -> Stanza {
        return errorResult(condition.type, errorCondition: condition.rawValue);
    }
    
    public func errorResult(errorType:String?, errorCondition:String, errorText:String? = nil, xmlns:String = "urn:ietf:params:xml:ns:xmpp-stanzas") -> Stanza {
        let elem = element;
        let response = Stanza.fromElement(elem);
        response.type = StanzaType.error;
        response.to = self.from;
        response.from = self.to;
        
        let errorEl = Element(name: "error");
        errorEl.setAttribute("type", value: errorType);
        
        let conditon = Element(name: errorCondition);
        conditon.xmlns = xmlns;
        errorEl.addChild(conditon);
        
        if errorText != nil {
            errorEl.addChild(Element(name: "text", cdata: errorText));
        }
        
        response.element.addChild(errorEl);
        return response;
    }
    
    public func makeResult(type:StanzaType) -> Stanza {
        let elem = Element(name: element.name, cdata: nil, attributes: element.attributes);
        let response = Stanza.fromElement(elem);
        response.to = self.from;
        response.from = self.to;
        response.type = type;
        return response;
    }
    
    func getElementValue(name:String?, xmlns:String? = nil) -> String? {
        return findChild(name, xmlns: xmlns)?.value;
    }
    
    func setElementValue(name:String, xmlns:String? = nil, value:String?) {
        element.forEachChild(name, xmlns: xmlns) { (e:Element) -> Void in
            self.element.removeChild(e);
        };
        if value != nil {
            element.addChild(Element(name: name, cdata: value!, xmlns: xmlns));
        }
    }
}

public class Message: Stanza {
    
    public var body:String? {
        get {
            return getElementValue("body");
        }
        set {
            setElementValue("body", value: newValue);
        }
    }
    
    public var subject:String? {
        get {
            return getElementValue("subject");
        }
        set {
            setElementValue("subject", value: newValue);
        }
    }
    
    public var thread:String? {
        get {
            return getElementValue("thread");
        }
        set {
            setElementValue("thread", value: newValue);
        }
    }
    
    public override var description: String {
        return String("Message : \(element.stringValue)")
    }
    
    public init() {
        super.init(name: "message", defStanzaType: StanzaType.normal);
    }
    
    public init(elem: Element) {
        super.init(elem: elem, defStanzaType: StanzaType.normal);
    }

}

public class Presence: Stanza {

    public enum Show: String {
        case chat
        case online
        case away
        case xa
        case dnd
        
        var weight:Int {
            switch self {
            case chat:
                return 5;
            case online:
                return 4;
            case away:
                return 3;
            case xa:
                return 2;
            case dnd:
                return 1;
            }
        }
    }
    
    public override var description: String {
        return String("Presence : \(element.stringValue)")
    }

    public var nickname:String? {
        get {
            return getElementValue("nick", xmlns: "http://jabber.org/protocol/nick");
        }
        set {
            setElementValue("nick", xmlns: "http://jabber.org/protocol/nick", value: newValue);
        }
    }
    
    public var priority:Int! {
        get {
            let x = findChild("priority")?.value;
            if x != nil {
                return Int(x!) ?? 0;
            }
            return 0;
        }
        set {
            element.forEachChild("priority") { (e:Element) -> Void in
                self.element.removeChild(e);
            };
            if newValue != nil {
                element.addChild(Element(name: "priority", cdata: newValue!.description));
            }
        }
    }
    
    public var show:Show? {
        get {
            let x = findChild("show")?.value;
            let type = self.type;
            if (x == nil) {
                if (type == nil || type == StanzaType.available) {
                    return .online;
                }
                return nil;
            }
            return Show(rawValue: x!);
        }
        set {
            element.forEachChild("show") { (e:Element) -> Void in
                self.element.removeChild(e);
            };
            if newValue != nil {
                element.addChild(Element(name: "show", cdata: newValue!.rawValue));
            }
        }
    }
    
    public var status:String? {
        get {
            return findChild("status")?.value;
        }
        set {
            element.forEachChild("status") { (e:Element) -> Void in
                self.element.removeChild(e);
            };
            if newValue != nil {
                element.addChild(Element(name: "status", cdata: newValue!));
            }
        }
    }
    
    public init() {
        super.init(name: "presence");
    }
    
    public init(elem: Element) {
        super.init(elem: elem);
    }

}

public class Iq: Stanza {

    public override var description: String {
        return String("Iq : \(element.stringValue)")
    }
    
    public init() {
        super.init(name: "iq");
    }
    
    public init(elem: Element) {
        super.init(elem: elem);
    }
    
}