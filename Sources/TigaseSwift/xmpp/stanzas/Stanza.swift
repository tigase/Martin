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
    
    enum ValueHolder<V> {
        case unset
        case value(V)
    }
    
    private var _lock = os_unfair_lock();
    private func withLock<T>(_ block: ()->T) -> T {
        os_unfair_lock_lock(&_lock)
        defer {
            os_unfair_lock_unlock(&_lock);
        }
        return block();
    }
    
    public var attributes: [String : String] {
        return element.attributes;
    }
    
    public var children: [Element] {
        return element.children;
    }
        
    public var debugDescription: String {
        String("Stanza : \(element.debugDescription)")
    }
    
    open var description: String {
        return element.description;
    }
    
    /// Keeps instance of root XML element
    public let element:Element;
    
    /// Returns information about delay in delivery of stanza
    open var delay:Delay? {
        if let delayEl = element.firstChild(name: "delay", xmlns: "urn:xmpp:delay") {
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
    
    private var from_: ValueHolder<JID?> = .unset;
    /**
     Sender address of stanza
     
     Value is cached after first time it is retrieved. Use this property 
     instead of direct modification of element `from` attribute.
     */
    open var from: JID? {
        get {
            withLock({
                switch from_ {
                case .unset:
                    let jid = JID(element.attribute("from"));
                    from_ = .value(jid);
                    return jid;
                case .value(let value):
                    return value;
                }
            })
        }
        set {
            withLock({
                from_ = .value(newValue);
                element.attribute("from", newValue: newValue?.description);
            })
        }
    }
    
    private var to_: ValueHolder<JID?> = .unset;
    /**
     Recipient address of stanza
     
     Value is cached after first time it is retrieved. Use this property
     instead of direct modification of element `to` attribute.
     */
    open var to:JID? {
        get {
            withLock({
                switch to_ {
                case .unset:
                    let jid = JID(element.attribute("to"));
                    to_ = .value(jid);
                    return jid;
                case .value(let value):
                    return value;
                }
            })
        }
        set {
            withLock({
                to_ = .value(newValue);
                element.attribute("to", newValue: newValue?.description);
            })
        }
    }
    
    /// Stanza id
    open var id:String? {
        get {
            return element.attribute("id");
        }
        set {
            element.attribute("id", newValue: newValue);
        }
    }
    
    private var type_: ValueHolder<StanzaType?> = .unset;
    /// Stanza type
    open var type:StanzaType? {
        get {
            withLock({
                switch type_ {
                case .unset:
                    let value = StanzaType(rawValue: element.attribute("type") ?? "");
                    type_ = .value(value);
                    return value;
                case .value(let value):
                    return value;
                }
            })
        }
        set {
            withLock({
                type_ = .value(newValue);
                element.attribute("type", newValue: newValue?.rawValue);
            })
        }
    }
    
    open var error: XMPPError? {
        get {
            return XMPPError(self);
        }
    }

    /// Returns XMLNS of element
    open var xmlns:String? {
        get {
            return element.xmlns;
        }
    }
    
    open var value: String? {
        get {
            return element.value;
        }
        set {
            element.value = newValue;
        }
    }

    public init(name: String, xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil, value: String? = nil) {
        self.element = Element(name: name, xmlns: xmlns);
        self.type = type;
        self.to = toJid;
        if let id = id {
            self.element.attribute("id", newValue: id);
        }
        if let value = value {
            self.element.value = value;
        }
    }
    
    public init(element: Element) {
        self.element = element;
    }
    
    open func addChild(_ child: Element) {
        self.element.addChild(child)
    }
    
    open func addChildren(_ children: [Element]) {
        self.element.addChildren(children);
    }
    
    public func attribute(_ key: String) -> String? {
        return element.attribute(key);
    }
    
    public func attribute(_ key: String, newValue: String?) {
        return element.attribute(key, newValue: newValue);
    }
    
    public func removeAttribute(_ key: String) {
        return element.removeAttribute(key);
    }
    
    public func firstChild(where body: (Element) -> Bool) -> Element? {
        return element.firstChild(where: body);
    }

    public func filterChildren(where body: (Element) -> Bool) -> Array<Element> {
        return element.filterChildren(where: body)
    }
    
    open func removeChild(_ child: Element) {
        self.element.removeChild(child);
    }

    open func removeChildren(where body: (Element)->Bool) {
        self.element.removeChildren(where: body);
    }
    
    /**
     Creates instance of proper class extending `Stanza` class based on element name.
     
     - returns:
        - Message: for elements named 'message'
        - Presence: for elements named 'presence'
        - Iq: for elements named 'iq'
        - Stanza: for any other elements not matching above rules
     */
    public static func from(element elem:Element) -> Stanza {
        switch elem.name {
        case "message":
            return Message(element:elem);
        case "presence":
            return Presence(element:elem);
        case "iq":
            return Iq(element:elem);
        default:
            return Stanza(element:elem);
        }
    }
    
    open func clone(shallow: Bool) -> Self {
        return Stanza.from(element: self.element.clone()) as! Self;
    }
    
    /**
     Creates stanza of type error with passsed error details.
     - returns: response stanza based on this stanza with error condition set
     */
    open func errorResult(of error: XMPPError) throws -> Self {
        guard type != .error && type != .result else {
            throw XMPPError(condition: .bad_request, stanza: self);
        }
        
        let response = clone();
        response.type = .error;
        response.to = self.from;
        response.from = self.to;

        response.addChild(error.element());

        return response;
    }
        
    /**
     Creates response stanza with following type set
     - parameter type: type to set in response stanza
     */
    open func makeResult(type: StanzaType) -> Stanza {
        let elem = Element(name: element.name, cdata: nil, attributes: element.attributes);
        let response = Stanza.from(element: elem);
        response.to = self.from;
        response.from = self.to;
        response.type = type;
        return response;
    }
    
    /// Returns value of matching element
    func getElementValue(name:String, xmlns:String? = nil) -> String? {
        return firstChild(name: name, xmlns: xmlns)?.value;
    }
    
    /// Creates new subelement with following name, xmlns and value. It will replace any other subelement with same name and xmlns
    func setElementValue(name:String, xmlns:String? = nil, value:String?) {
        element.removeChildren(name: name, xmlns: xmlns);
        if value != nil {
            element.addChild(Element(name: name, cdata: value!, xmlns: xmlns));
        }
    }
}

// implementation of deprecated methods
extension Stanza {
    
    @available(*, deprecated, renamed: "firstChild")
    open func findChild(name:String? = nil, xmlns:String? = nil) -> Element? {
        return self.element.findChild(name: name, xmlns: xmlns);
    }
    @available(*, deprecated, renamed: "firstChild")
    open func findChild(where body: (Element) -> Bool) -> Element? {
        return self.element.findChild(where: body);
    }
    @available(*, deprecated, message: "Method removed")
    public func firstIndex(ofChild child: Element) -> Int? {
        return self.element.firstIndex(ofChild: child);
    }
    @available(*, deprecated, renamed: "filterChildren")
    open func getChildren(name:String? = nil, xmlns:String? = nil) -> Array<Element> {
        return self.element.getChildren(name: name, xmlns: xmlns);
    }
    @available(*, deprecated, renamed: "filterChildren")
    open func getChildren(where body: (Element) -> Bool) -> Array<Element> {
        return self.element.getChildren(where: body);
    }
    @available(*, deprecated, renamed: "attribute(_:)")
    open func getAttribute(_ key:String) -> String? {
        return self.element.getAttribute(key);
    }
    
    @available(*, deprecated, renamed: "attribute(_:newValue:)")
    open func setAttribute(_ key:String, value:String?) {
        self.element.setAttribute(key, value: value);
    }
    
}

