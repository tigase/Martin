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
 
 Value of `to`/`from` attributes is cached on instance level. After `Stanza` is created from element do not modify element
 `to`/`from` attributes directly - instead use `to`/`from` properties of `Stanza` class.
 */
open class Stanza: ElementProtocol, CustomStringConvertible {
    
    fileprivate let defStanzaType:StanzaType?;
    
    open var description: String {
        return String("Stanza : \(element.stringValue)")
    }
    
    /// Keeps instance of root XML element
    open let element:Element;
    
    /// Returns information about delay in delivery of stanza
    open var delay:Delay? {
        if let delayEl = element.findChild(name: "delay", xmlns: "urn:xmpp:delay") {
            return Delay(element: delayEl);
        }
        return nil;
    }
    
    /// Returns element name
    open var name:String {
        get {
            return element.name;
        }
    }
    
    fileprivate var from_: JID?;
    /**
     Sender address of stanza
     
     Value is cached after first time it is retrieved. Use this property 
     instead of direct modification of element `from` attribute.
     */
    open var from:JID? {
        get {
            if let jidStr = element.getAttribute("from") {
                from_ = JID(jidStr);
            }
            return from_;
        }
        set {
            from_ = newValue;
            element.setAttribute("from", value: newValue?.stringValue);
        }
    }
    
    fileprivate var to_: JID?;
    /**
     Recipient address of stanza
     
     Value is cached after first time it is retrieved. Use this property
     instead of direct modification of element `to` attribute.
     */
    open var to:JID? {
        get {
            if let jidStr = element.getAttribute("to") {
                to_ = JID(jidStr);
            }
            return to_;
        }
        set {
            to_ = newValue;
            element.setAttribute("to", value:newValue?.stringValue);
        }
    }
    
    /// Stanza id
    open var id:String? {
        get {
            return element.getAttribute("id");
        }
        set {
            element.setAttribute("id", value: newValue);
        }
    }
    
    
    /// Stanza type
    open var type:StanzaType? {
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
    open var errorCondition:ErrorCondition? {
        get {
            if type != StanzaType.error {
                return nil;
            }
            if let name = element.findChild(name: "error")?.findChild(xmlns:"urn:ietf:params:xml:ns:xmpp-stanzas")?.name {
                return ErrorCondition(rawValue: name);
            }
            return nil;
        }
    }

    /// Returns XMLNS of element
    open var xmlns:String? {
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
    
    open func addChild(_ child: Element) {
        self.element.addNode(child)
    }
    
    open func addChildren(_ children: [Element]) {
        self.element.addChildren(children);
    }
    
    open func findChild(name:String? = nil, xmlns:String? = nil) -> Element? {
        return self.element.findChild(name: name, xmlns: xmlns);
    }
    
    open func getChildren(name:String? = nil, xmlns:String? = nil) -> Array<Element> {
        return self.element.getChildren(name: name, xmlns: xmlns);
    }
    
    open func getAttribute(_ key:String) -> String? {
        return self.element.getAttribute(key);
    }
    
    open func removeChild(_ child: Element) {
        self.element.removeChild(child);
    }
    
    open func setAttribute(_ key:String, value:String?) {
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
    open static func from(element elem:Element) -> Stanza {
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
    open func errorResult(condition:ErrorCondition, text:String? = nil) -> Stanza {
        return errorResult(errorType: condition.type, errorCondition: condition.rawValue);
    }
    
    open func errorResult(errorType:String?, errorCondition:String, errorText:String? = nil, xmlns:String = "urn:ietf:params:xml:ns:xmpp-stanzas") -> Stanza {
        let elem = element;
        let response = Stanza.from(element: elem);
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
    open func makeResult(type:StanzaType) -> Stanza {
        let elem = Element(name: element.name, cdata: nil, attributes: element.attributes);
        let response = Stanza.from(element: elem);
        response.to = self.from;
        response.from = self.to;
        response.type = type;
        return response;
    }
    
    /// Returns value of matching element
    func getElementValue(name:String?, xmlns:String? = nil) -> String? {
        return findChild(name: name, xmlns: xmlns)?.value;
    }
    
    /// Creates new subelement with following name, xmlns and value. It will replace any other subelement with same name and xmlns
    func setElementValue(name:String, xmlns:String? = nil, value:String?) {
        element.forEachChild(name: name, xmlns: xmlns) { (e:Element) -> Void in
            self.element.removeChild(e);
        };
        if value != nil {
            element.addChild(Element(name: name, cdata: value!, xmlns: xmlns));
        }
    }
}

/// Extenstion of `Stanza` class with specific features existing only in `message' elements.
open class Message: Stanza {
    
    /// Message plain text
    open var body:String? {
        get {
            return getElementValue(name: "body");
        }
        set {
            setElementValue(name: "body", value: newValue);
        }
    }
    
    /// Message subject
    open var subject:String? {
        get {
            return getElementValue(name: "subject");
        }
        set {
            setElementValue(name: "subject", value: newValue);
        }
    }
    
    /// Message thread id
    open var thread:String? {
        get {
            return getElementValue(name: "thread");
        }
        set {
            setElementValue(name: "thread", value: newValue);
        }
    }
    
    open override var description: String {
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
open class Presence: Stanza {

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
            case .chat:
                return 5;
            case .online:
                return 4;
            case .away:
                return 3;
            case .xa:
                return 2;
            case .dnd:
                return 1;
            }
        }
    }
    
    open override var description: String {
        return String("Presence : \(element.stringValue)")
    }

    /// Suggested nickname to use
    open var nickname:String? {
        get {
            return getElementValue(name: "nick", xmlns: "http://jabber.org/protocol/nick");
        }
        set {
            setElementValue(name: "nick", xmlns: "http://jabber.org/protocol/nick", value: newValue);
        }
    }
    
    /// Priority of presence and resource connection
    open var priority:Int! {
        get {
            let x = findChild(name: "priority")?.value;
            if x != nil {
                return Int(x!) ?? 0;
            }
            return 0;
        }
        set {
            element.forEachChild(name: "priority") { (e:Element) -> Void in
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
    open var show:Show? {
        get {
            let x = findChild(name: "show")?.value;
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
            element.forEachChild(name: "show") { (e:Element) -> Void in
                self.element.removeChild(e);
            };
            if newValue != nil && newValue != Show.online {
                element.addChild(Element(name: "show", cdata: newValue!.rawValue));
            }
        }
    }
    
    /// Text with additional description - mainly for human use
    open var status:String? {
        get {
            return findChild(name: "status")?.value;
        }
        set {
            element.forEachChild(name: "status") { (e:Element) -> Void in
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

/// Extenstion of `Stanza` class with specific features existing only in `iq` elements.
open class Iq: Stanza {

    open override var description: String {
        return String("Iq : \(element.stringValue)")
    }
    
    public init() {
        super.init(name: "iq");
    }
    
    public init(elem: Element) {
        super.init(elem: elem);
    }
    
}
