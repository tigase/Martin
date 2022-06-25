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
    
    private var from_: JID?;
    /**
     Sender address of stanza
     
     Value is cached after first time it is retrieved. Use this property 
     instead of direct modification of element `from` attribute.
     */
    open var from:JID? {
        get {
            withLock({
                if from_ == nil, let jidStr = element.attribute("from") {
                    from_ = JID(jidStr);
                }
                return from_;
            })
        }
        set {
            withLock({
                from_ = newValue;
                element.attribute("from", newValue: newValue?.description);
            })
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
            withLock({
                if to_ == nil, let jidStr = element.attribute("to") {
                    to_ = JID(jidStr);
                }
                return to_;
            })
        }
        set {
            withLock({
                to_ = newValue;
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
    
    
    /// Stanza type
    open var type:StanzaType? {
        get {
            if let type = element.attribute("type") {
                return StanzaType(rawValue: type);
            }
            return nil;
        }
        set {
            element.attribute("type", newValue: newValue?.rawValue);
        }
    }
    
    open var error: XMPPError? {
        get {
            return XMPPError.parse(stanza: self);
        }
    }
    
    /// Returns error condition due to which this response stanza is marked as an error
    @available(*, deprecated, message: "Use `error` property instead")
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
    
    /// Returns error text associated with this error stanza
    @available(*, deprecated, message: "Use `error` property instead")
    open var errorText: String? {
        get {
            if type != StanzaType.error {
                return nil;
            }
            return element.findChild(name: "error")?.findChild(name: "text")?.value;
        }
    }

    /// Returns XMLNS of element
    open var xmlns:String? {
        get {
            return element.xmlns;
        }
    }
        
    init(name: String, xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil) {
        self.element = Element(name: name, xmlns: xmlns);
        self.type = type;
        self.to = toJid;
        if let id = id {
            self.element.attribute("id", newValue: id);
        }
    }
    
    init(elem: Element) {
        self.element = elem;
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
            return Message(elem:elem);
        case "presence":
            return Presence(elem:elem);
        case "iq":
            return Iq(elem:elem);
        default:
            return Stanza(elem:elem);
        }
    }
    
    open func errorResult(of error: XMPPError) -> Stanza {
        let elem = Element(element: element);
        let response = Stanza.from(element: elem);
        response.type = StanzaType.error;
        response.to = self.from;
        response.from = self.to;

        response.element.addChild(error.element());

        return response;
    }
    
    /**
     Creates stanza of type error with passsed error condition.
     - returns: response stanza based on this stanza with error condition set
     */
    @available(* , deprecated, message: "Use errorResult(of:) method accepting XMPPError")
    open func errorResult(condition:ErrorCondition, text:String? = nil) -> Stanza {
        return errorResult(errorType: condition.type, errorCondition: condition.rawValue);
    }
    
    open func errorResult(errorType:String?, errorCondition:String, errorText:String? = nil, xmlns:String = "urn:ietf:params:xml:ns:xmpp-stanzas") -> Stanza {
        let elem = Element(element: element);
        let response = Stanza.from(element: elem);
        response.type = StanzaType.error;
        response.to = self.from;
        response.from = self.to;
        
        let errorEl = Element(name: "error");
        errorEl.attribute("type", newValue: errorType);
        
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
    
    /// Message OOB url
    open var oob: String? {
        get {
            return firstChild(name: "x", xmlns: "jabber:x:oob")?.firstChild(name: "url")?.value;
        }
        set {
            element.removeChildren(name: "x", xmlns: "jabber:x:oob");
            if newValue != nil {
                let x = Element(name: "x", xmlns: "jabber:x:oob");
                x.addChild(Element(name: "url", cdata: newValue))
                element.addChild(x);
            }
        }
    }
    
    open var hints: [ProcessingHint] {
        get {
            return ProcessingHint.from(message: self);
        }
        set {
            element.removeChildren(where: { (el) -> Bool in
                return el.xmlns == "urn:xmpp:hints";
            });
            element.addChildren(newValue.map({ $0.element() }));
        }
    }
    
    open override var debugDescription: String {
        return String("Message : \(element)")
    }
    
    public init(xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil) {
        super.init(name: "message", xmlns: xmlns, type: type, id: id, to: toJid);
    }
    
    public override init(elem: Element) {
        super.init(elem: elem);
    }

    public enum ProcessingHint {
        case noPermanentStore
        case noCopy
        case noStore
        case store
        
        var elemName: String {
            switch self {
            case .noPermanentStore:
                return "no-permanent-store";
            case .noStore:
                return "no-store";
            case .noCopy:
                return "no-copy";
            case .store:
                return "store";
            }
        }
        
        public func element() -> Element {
            return Element(name: elemName, xmlns: "urn:xmpp:hints");
        }
        
        public static func from(element el: Element) -> ProcessingHint? {
            guard el.xmlns == "urn:xmpp:hints" else {
                return nil;
            }
            switch el.name {
            case "no-permanent-store":
                return .noPermanentStore;
            case "no-store":
                return .noStore;
            case "no-copy":
                return .noCopy;
            case "store":
                return .store;
            default:
                return nil;
            }
        }
                
        public static func from(message: Message) -> [ProcessingHint] {
            return message.element.children.compactMap(ProcessingHint.from(element:));
        }
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
        
        public var weight:Int {
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
    
    open override var debugDescription: String {
        return String("Presence : \(element)")
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
            let x = firstChild(name: "priority")?.value;
            if x != nil {
                return Int(x!) ?? 0;
            }
            return 0;
        }
        set {
            element.removeChildren(name: "priority");
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
            let x = firstChild(name: "show")?.value;
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
            element.removeChildren(name: "show");
            if newValue != nil && newValue != Show.online {
                element.addChild(Element(name: "show", cdata: newValue!.rawValue));
            }
        }
    }
    
    /// Text with additional description - mainly for human use
    open var status:String? {
        get {
            return firstChild(name: "status")?.value;
        }
        set {
            element.removeChildren(name: "status");
            if newValue != nil {
                element.addChild(Element(name: "status", cdata: newValue!));
            }
        }
    }
    
    public init(xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil) {
        super.init(name: "presence", xmlns: xmlns, type: type, id: id, to: toJid);
    }
    
    public override init(elem: Element) {
        super.init(elem: elem);
    }

}

/// Extenstion of `Stanza` class with specific features existing only in `iq` elements.
open class Iq: Stanza {

    open override var debugDescription: String {
        return String("Iq : \(element)")
    }
    
    public init(xmlns: String? = nil, type: StanzaType? = nil, id: String? = nil, to toJid: JID? = nil) {
        super.init(name: "iq", xmlns: xmlns, type: type, id: id, to: toJid);
    }
    
    public override init(elem: Element) {
        super.init(elem: elem);
    }
    
}
