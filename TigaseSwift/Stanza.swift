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

public class Stanza: CustomStringConvertible {
    
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
            return nil;
        }
        set {
            element.setAttribute("type", value: newValue?.rawValue);
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

    init(name:String) {
        self.element = Element(name: name);
    }
    
    init(elem:Element) {
        self.element = elem;
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
}

public class Message: Stanza {
  
    public override var description: String {
        return String("Message : \(element.stringValue)")
    }
    
    public init() {
        super.init(name: "message");
    }
    
    public override init(elem: Element) {
        super.init(elem: elem);
    }

}

public class Presence: Stanza {

    public override var description: String {
        return String("Presence : \(element.stringValue)")
    }
    
    public init() {
        super.init(name: "presence");
    }
    
    public override init(elem: Element) {
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
    
    public override init(elem: Element) {
        super.init(elem: elem);
    }
    
}