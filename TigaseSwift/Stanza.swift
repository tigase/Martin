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

/**
 Stanza class is a wrapper/helper for any root XML element receved from XMPP stream or which will be sent by XMPP stream.
 */
public class Stanza: ElementProtocol, CustomStringConvertible {
    
    private let defStanzaType:StanzaType?;
    
    public var description: String {
        return String("Stanza : \(element.stringValue)")
    }
    
    /// Keeps instance of root XML element
    public let element:Element;
    
    /// Returns information about delay in delivery of stanza
    public var delay:Delay? {
        if let delayEl = element.findChild("delay", xmlns: "urn:xmpp:delay") {
            return Delay(element: delayEl);
        }
        return nil;
    }
    
    /// Returns element name
    public var name:String {
        get {
            return element.name;
        }
    }
    
    /// Sender address of stanza
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
    
    /// Recipient address of stanza
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
    
    /// Stanza id
    public var id:String? {
        get {
            return element.getAttribute("id");
        }
        set {
            element.setAttribute("id", value: newValue);
        }
    }
    
    
    /// Stanza type
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
    
    /// Returns error condition due to which this response stanza is marked as an error
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

    /// Returns XMLNS of element
    public var xmlns:String? {
        get {
            return element.xmlns;
        }
    }
    
    init(name:String, defStanzaType:StanzaType? = nil, xmlns: String? = nil) {
        self.element = Element(name: name, xmlns: xmlns);
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
    
    /**
     Creates instance of proper class extending `Stanza` class based on element name.
     
     - returns:
        - Message: for elements named 'message'
        - Presence: for elements named 'presence'
        - Iq: for elements named 'iq'
        - Stanza: for any other elements not matching above rules
     */
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
    
    /**
     Creates stanza of type error with passsed error condition.
     - returns: response stanza based on this stanza with error condition set
     */
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
    
    /**
     Creates response stanza with following type set
     - parameter type: type to set in response stanza
     */
    public func makeResult(type:StanzaType) -> Stanza {
        let elem = Element(name: element.name, cdata: nil, attributes: element.attributes);
        let response = Stanza.fromElement(elem);
        response.to = self.from;
        response.from = self.to;
        response.type = type;
        return response;
    }
    
    /// Returns value of matching element
    func getElementValue(name:String?, xmlns:String? = nil) -> String? {
        return findChild(name, xmlns: xmlns)?.value;
    }
    
    /// Creates new subelement with following name, xmlns and value. It will replace any other subelement with same name and xmlns
    func setElementValue(name:String, xmlns:String? = nil, value:String?) {
        element.forEachChild(name, xmlns: xmlns) { (e:Element) -> Void in
            self.element.removeChild(e);
        };
        if value != nil {
            element.addChild(Element(name: name, cdata: value!, xmlns: xmlns));
        }
    }
}

/// Extenstion of `Stanza` class with specific features existing only in `message' elements.
public class Message: Stanza {
    
    /// Message plain text
    public var body:String? {
        get {
            return getElementValue("body");
        }
        set {
            setElementValue("body", value: newValue);
        }
    }
    
    /// Message subject
    public var subject:String? {
        get {
            return getElementValue("subject");
        }
        set {
            setElementValue("subject", value: newValue);
        }
    }
    
    /// Message thread id
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

/// Extenstion of `Stanza` class with specific features existing only in `presence' elements.
public class Presence: Stanza {

    /**
     Possible values:
     - chat: sender of stanza is ready to chat
     - online: sender of stanza is online
     - away: sender of stanza is away
     - xa: sender of stanza is away for longer time (eXtender Away)
     - dnd: sender of stanza wishes not to be disturbed
     */
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

    /// Suggested nickname to use
    public var nickname:String? {
        get {
            return getElementValue("nick", xmlns: "http://jabber.org/protocol/nick");
        }
        set {
            setElementValue("nick", xmlns: "http://jabber.org/protocol/nick", value: newValue);
        }
    }
    
    /// Priority of presence and resource connection
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
    
    /**
     Show value of this presence:
     - if available then is value from `Show` enum
     - if unavailable then is nil
     */
    public var show:Show? {
        get {
            let x = findChild("show")?.value;
            let type = self.type;
            guard type != StanzaType.error && type != StanzaType.unavailable else {
                return nil;
            }
            
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
            if newValue != nil && newValue != Show.online {
                element.addChild(Element(name: "show", cdata: newValue!.rawValue));
            }
        }
    }
    
    /// Text with additional description - mainly for human use
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

/// Extenstion of `Stanza` class with specific features existing only in `iq' elements.
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