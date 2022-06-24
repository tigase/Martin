//
// Element.swift
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

public enum Node: CustomStringConvertible, Equatable {
    
    public static func == (lhs: Node, rhs: Node) -> Bool {
        switch lhs {
        case .element(let lel):
            switch rhs {
            case .element(let rel):
                return lel === rel;
            default:
                return false;
            }
        case .cdata(let lstr):
            switch rhs {
            case .cdata(let rstr):
                return lstr == rstr;
            default:
                return false;
            }
        }
    }
    
    case element(Element)
    case cdata(String)
    
    public var description: String {
        switch self {
        case .element(let el):
            return el.description;
        case .cdata(let str):
            return EscapeUtils.escape(str);
        }
    }
    
    public func prettyString(secure: Bool) -> String {
        switch self {
        case .element(let el):
            return el.prettyString(secure: secure);
        case .cdata(let str):
            return EscapeUtils.escape(str);
        }
    }

}

/**
 Class representing parsed XML element
 */
public final class Element : CustomStringConvertible, CustomDebugStringConvertible, ElementProtocol {
    /// Element name
    public let name:String
    var _defxmlns:String?
    private var _attributes:[String:String];
    private var _nodes: [Node];
    private var _lock = os_unfair_lock();
    
    /// XMLNS of element
    public var xmlns:String? {
        get {
            return withLock({
                return _attributes["xmlns"] ?? _defxmlns;
            })
        }
        set {
            withLock({
                if (newValue == nil || newValue == _defxmlns) {
                    _attributes.removeValue(forKey: "xmlns");
                } else {
                    _attributes["xmlns"] = newValue;
                }
            })
        }
    }
    
    private func withLock<T>(_ block: ()->T) -> T {
        os_unfair_lock_lock(&_lock)
        defer {
            os_unfair_lock_unlock(&_lock);
        }
        return block();
    }
    
    private var _children: [Element] {
        return _nodes.compactMap({ node in
            guard case let .element(el) = node else {
                return nil;
            }
            return el;
        });
    }
        
    public var description: String {
        return withLock({
            var result = "<\(self.name)"
            for (k,v) in _attributes {
                let val = EscapeUtils.escape(v);
                result += " \(k)='\(val)'"
            }
            if (!_nodes.isEmpty) {
                result += ">"
                for child in _nodes {
                    result += child.description;
                }
                result += "</\(self.name)>"
            } else {
                result += "/>"
            }
            return result;
        })
    }
    
    public var debugDescription: String {
        return prettyString(secure: true);
    }
    
    /// Attributes of XML element
    public var attributes: [String:String] {
        withLock({
            return self._attributes;
        })
    }
    
    public var children: [Element] {
        return withLock({
            return _children;
        })
    }
    
    /// Check if element contains subelements
    public var hasChildren:Bool {
        return withLock({
            return !_nodes.isEmpty && !_children.isEmpty;
        })
    }
    
    /// Value of cdata of this element
    public var value:String? {
        get {
            withLock({ () -> String? in
                let cdata: [String] = _nodes.compactMap({ node in
                    guard case let .cdata(val) = node else {
                        return nil;
                    }
                    return val;
                });
                return cdata.isEmpty ? nil : cdata.joined(separator: "");
            })
        }
        set {
            withLock({
                _nodes.removeAll();
                if let val = newValue {
                    _nodes.append(.cdata(val));
                }
            })
        }
    }
        
    public convenience init(name: String, xmlns: String? = nil, children: [Element]) {
        self.init(name: name, attributes: [:], nodes: children.map({ .element($0) }));
        self.xmlns = xmlns;
    }
    
    public convenience init(name: String, xmlns: String? = nil, cdata: String) {
        self.init(name: name, attributes: [:], nodes: [.cdata(cdata)]);
        self.xmlns = xmlns;
    }
    
    /**
     Creates instance of `Element`
     - parameter name: name of element
     - parameter cdata: value of element
     - parameter attributes: attributes of element
     */
    public init(name: String, cdata: String? = nil, attributes: [String:String]) {
        self.name = name;
        if let cdata = cdata {
            self._nodes = [.cdata(cdata) ];
        } else {
            self._nodes = [];
        }
        self._attributes = attributes;
        
        
    }
    
    /**
     Creates instance of `Element`
     - parameter name: name of element
     - parameter cdata: value of element
     - parameter xmlns: xmlns of element
     */
    public init(name: String, cdata:String? = nil, xmlns: String? = nil) {
        self.name = name;
        self._attributes =  [String:String]();
        if let cdata = cdata {
            self._nodes = [.cdata(cdata)];
        } else {
            self._nodes = [];
        }
        self.xmlns = xmlns;
    }
    
    public init(name: String, attributes: [String:String], nodes: [Node]) {
        self.name = name;
        self._attributes = attributes;
        self._nodes = nodes;
    }
    
    public convenience init(element: Element) {
        let (attrs,nodes) = element.withLock({
            return (element._attributes, element._nodes);
        })
        self.init(name: element.name, attributes: attrs, nodes: nodes);
    }
    
    /**
     Add subelement
     - parameter child: element to add as subelement
     */
    public func addChild(_ child: Element) {
        self.addNode(.element(child));
    }
    
    /**
     Add subelements
     - parameter children: array of elements to add as subelements
     */
    public func addChildren(_ children: [Element]) {
        withLock({
            self._nodes.append(contentsOf: children.map({ .element($0) }));
        })
    }
    
    public func addNode(_ child: Node) {
        withLock({
            self._nodes.append(child)
        })
    }
    
    /**
     In subelements finds element for which passed closure returns true
     - parameter where: element matcher
     - returns: first element which matches
     */
    public func firstChild(where body: (Element)->Bool) -> Element? {
        return children.first(where: body);
    }
    
    /**
     Finds every matching child element
     - parameter where: matcher closure
     - returns: array of matching elements
     */
    public func filterChildren(where body: (Element)->Bool) -> Array<Element> {
        withLock({
            return _children.filter(body);
        })
    }

    /**
     Returns value of attribute
     - parameter key: attribute name
     - returns: value for attribute
     */
    public func attribute(_ key: String) -> String? {
        return withLock({
            return _attributes[key];
        })
    }
    
    /**
     Set value for attribute
     - parameter key: attribute to set
     - parameter newValue: value to set
     */
    public func attribute(_ key: String, newValue: String?) {
        if let value = newValue {
            withLock({
                _ = self._attributes[key] = value;
            })
        } else {
            removeAttribute(key);
        }
    }
    
    public func removeAttribute(_ key: String) {
        withLock({
            _ = self._attributes.removeValue(forKey: key);
        })
    }
        
    /**
     Removes element instance from children (comparison by reference).

     **WARNING:** only the same instance of Element will be removed!
     - parameter child: element to remove
     */
    public func removeChild(_ child: Element) {
        return withLock({
            self._nodes.removeAll(where: { node in
                guard case let .element(el) = node else {
                    return false;
                }
                return el === child;
            })
        })
    }
    
    /**
     Remove mathing elements from child elements
     - parameter where: matcher closure
     */
    public func removeChildren(where body: (Element)->Bool) {
        return withLock({
            self._nodes.removeAll(where: { node in
                guard case let .element(el) = node else {
                    return false;
                }
                return body(el);
            })
        })
    }

    /**
     Removes node from children
     */
    public func removeNode(_ child: Node) {
        return withLock({
            self._nodes.removeAll(where: { $0 == child })
        })
    }
    
    func setDefXMLNS(_ defxmlns:String?) {
        withLock({
            self._defxmlns = defxmlns;
        })
    }
    
    public func prettyString(secure: Bool) -> String {
        withLock({
            var result = "<\(self.name)"
            for (k,v) in _attributes {
                let val = EscapeUtils.escape(v);
                result += " \(k)='\(val)'"
            }
            if (!_nodes.isEmpty) {
                result += ">"
                for node in _nodes {
                    switch node {
                    case .cdata(let str):
                        result += EscapeUtils.escape(str);
                    case .element(let child):
                        result += "\n\(child.prettyString(secure: secure))"
                    }
                }
                result += "</\(self.name)>"
            } else {
                result += "/>"
            }
            return result;
        })
    }
    
    /**
     Convenience function for parsing string with XML to create elements
     - parameter string: string with XML to parse
     - returns: parsed Element if any
     */
    public static func from(string toParse: String) -> Element? {
        class Holder: XMPPStreamDelegate {
            var parsed:Element?;
            fileprivate func onError(msg: String?) {
            }
            fileprivate func onStreamStart(attributes: [String : String]) {
            }
            fileprivate func onStreamTerminate(reason: SocketConnector.State.DisconnectionReason) {
            }
            fileprivate func process(element packet: Element) {
                parsed = packet;
            }
        }
        
        let xmlDelegate = XMPPParserDelegate();
        let parser = XMLParser(delegate: xmlDelegate);
        let data = toParse.data(using: String.Encoding.utf8);
        try? parser.parse(data: data!);
        return xmlDelegate.parsed.first;
    }
}

// deprecated methods
extension Element {
    
    /**
     Creates instance of `Element`
     - parameter name: name of element
     - parameter cdata: value of element
     - parameter xmlns: xmlns of element
     - parameter children: list of child elements
     */
    @available(*, deprecated, message: "Method removed")
    public convenience init(name: String, cdata:String? = nil, xmlns: String? = nil, children: [Element]) {
        self.init(name: name, xmlns: xmlns, children: children);
        if let cdata = cdata {
            self._nodes.append(.cdata(cdata));
        }
    }
    
    @available(*, deprecated, renamed: "firstChild")
    public func findChild(name: String? = nil, xmlns: String? = nil) -> Element? {
        guard let name = name else {
            guard let xmlns = xmlns else {
                return firstChild();
            }
            return firstChild(xmlns: xmlns);
        }
        return firstChild(name: name, xmlns: xmlns);
    }

    @available(*, deprecated, renamed: "firstChild")
    public func findChild(where body: (Element)->Bool) -> Element? {
        return firstChild(where: body);
    }
    
    @available(*, deprecated, message: "Removed, use children.first")
    public func firstChild() -> Element? {
        return children.first;
    }
    
    /**
     For every child element matching name and xmlns executes closure
     - parameter name: name of child element
     - parameter xmlns: xmlns of child element
     - parameter fn: closure to execute
     */
    @available(*, deprecated, message: "Method removed, use children.filter(where:).map(_:)")
    public func forEachChild(name:String? = nil, xmlns:String? = nil, fn: (Element)->Void) {
        if let name = name {
            filterChildren(name: name, xmlns: xmlns).forEach(fn);
        } else if let xmlns = xmlns {
            children.filter({ $0.xmlns == xmlns }).forEach(fn);
        } else {
            children.forEach(fn);
        }
    }
    
    
    /**
     Filters subelements array using provided filter and for matching elements executes
     transformation closure converting this array into array of objects returned by
     transformation closure.
     
     If transformation will return nil - result will not be added to returned array
     - parameter transformation: closure used for transformation
     - parameter filter: closure used for filtering child elements
     - returns: array of objects returned by transformation closure
     */
    @available(*, deprecated, message: "Method removed, use children.filter(where:).compactMap(_:)")
    public func mapChildren<U>(transform: (Element) -> U?, filter: ((Element) -> Bool)? = nil) -> [U] {
        var tmp = children;
        if filter != nil {
            tmp = tmp.filter({ e -> Bool in
                return filter!(e);
            });
        };
        var result = [U]();
        for e in tmp {
            if let u = transform(e) {
                result.append(u);
            }
        }
        return result;
    }
    
    /**
     Finds first index at which this child is found (comparison by reference).
     */
    @available(*, deprecated, message: "Method removed")
    public func firstIndex(ofChild child: Element) -> Int? {
        return children.firstIndex(where: { $0 === child });
    }
    
    @available(*, deprecated, renamed: "filterChildren")
    public func getChildren(name:String? = nil, xmlns:String? = nil) -> Array<Element> {
        guard let name = name else {
            return children.filter({ xmlns == nil || $0.xmlns == xmlns });
        }
        
        return filterChildren(name: name, xmlns: xmlns);
    }

    /**
     Finds every child element for which matcher returns true
     - parameter where: matcher closure
     - returns: array of matching elements
     */
    @available(*, deprecated, message: "Method removed, use children.filter(where:)")
    public func getChildren(where body: (Element)->Bool) -> Array<Element> {
        return children;
    }
    
    @available(*, deprecated, renamed: "attribute(_:)")
    public func getAttribute(_ key:String) -> String? {
        return withLock({
            return _attributes[key];
        })
    }

    /**
     Set value for attribute
     - parameter key: attribute to set
     - parameter value: value to set
     */
    @available(*, deprecated, renamed: "attribute(_:newValue:)")
    public func setAttribute(_ key:String, value:String?) {
        withLock({
            if (value == nil) {
                _attributes.removeValue(forKey: key);
            } else {
                _attributes[key] = value;
            }
        })
    }

}
