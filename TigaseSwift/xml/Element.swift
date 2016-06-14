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

/**
 Class representing parsed XML element
 */
public class Element : Node, ElementProtocol {
    /// Element name
    public let name:String
    var defxmlns:String?
    private var attributes_:[String:String];
    private var nodes = Array<Node>()
    
    /// Attributes of XML element
    public var attributes:[String:String] {
        get {
            return self.attributes_;
        }
    }
    
    /// Check if element contains subelements
    public var hasChildren:Bool {
        return !nodes.isEmpty && !getChildren().isEmpty;
    }
    
    /// Value of cdata of this element
    public var value:String? {
        get {
            var result:String? = nil;
            for node in nodes {
                if let cdata = node as? CData {
                    if result == nil {
                        result = cdata.value;
                    } else {
                        result = result! + cdata.value;
                    }
                }
            }
            return result;
        }
        set {
            nodes.removeAll();
            if newValue != nil {
                nodes.append(CData(value: newValue!));
            }
        }
    }
    
    /**
     Creates instance of `Element`
     - parameter name: name of element
     - parameter cdata: value of element
     - parameter attributes: attributes of element
     */
    public init(name: String, cdata: String? = nil, attributes: [String:String]) {
        self.name = name;
        if (cdata != nil) {
            self.nodes.append(CData(value: cdata!));
        }
        self.attributes_ = attributes;
    }
    
    /**
     Creates instance of `Element`
     - parameter name: name of element
     - parameter cdata: value of element
     - parameter xmlns: xmlns of element
     */
    public init(name: String, cdata:String? = nil, xmlns: String? = nil) {
        self.name = name;
        self.attributes_ =  [String:String]();
        super.init();
        self.xmlns = xmlns;
        if (cdata != nil) {
            self.nodes.append(CData(value: cdata!));
        }
    }
    
    /**
     Add subelement
     - parameter child: element to add as subelement
     */
    public func addChild(child: Element) {
        self.addNode(child)
    }
    
    /**
     Add subelements
     - parameter children: array of elements to add as subelements
     */
    public func addChildren(children: [Element]) {
        children.forEach { (c) in
            self.addChild(c);
        }
    }
    
    func addNode(child:Node) {
        self.nodes.append(child)
    }
    
    /**
     In subelements finds element with matching name and/or xmlns and returns it
     - parameter name: name of element to find
     - parameter xmlns: xmlns of element to find
     - returns: first element which name and xmlns matches
     */
    public func findChild(name:String? = nil, xmlns:String? = nil) -> Element? {
        for node in nodes {
            if (node is Element) {
                let elem = node as! Element;
                if name != nil {
                    if elem.name != name! {
                        continue;
                    }
                }
                if xmlns != nil {
                    if elem.xmlns != xmlns! {
                        continue;
                    }
                }
                return elem;
            }
        }
        return nil;
    }
    
    /**
     Find first child element
     returns: first child element
     */
    public func firstChild() -> Element? {
        for node in nodes {
            if (node is Element) {
                return node as? Element;
            }
        }
        return nil;
    }
    
    /**
     For every child element matching name and xmlns executes closure
     - parameter name: name of child element
     - parameter xmlns: xmlns of child element
     - parameter fn: closure to execute
     */
    public func forEachChild(name:String? = nil, xmlns:String? = nil, fn: (Element)->Void) {
        for node in nodes {
            if (node is Element) {
                let elem = node as! Element;
                if name != nil {
                    if elem.name != name! {
                        continue;
                    }
                }
                if xmlns != nil {
                    if elem.xmlns != xmlns! {
                        continue;
                    }
                }
                fn(elem);
            }
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
    public func mapChildren<U>(transform: (Element) -> U?, filter: ((Element) -> Bool)? = nil) -> [U] {
        var tmp = getChildren();
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
     Finds every child element with matching name and xmlns
     - parameter name: name of child element
     - parameter xmlns: xmlns of child element
     - returns: array of matching elements
     */
    public func getChildren(name:String? = nil, xmlns:String? = nil) -> Array<Element> {
        var result = Array<Element>();
        for node in nodes {
            if (node is Element) {
                let elem = node as! Element;
                if name != nil {
                    if elem.name != name! {
                        continue;
                    }
                }
                if xmlns != nil {
                    if elem.xmlns != xmlns! {
                        continue;
                    }
                }
                result.append(node as! Element)
            }
        }
        return result;
    }
    
    /**
     Returns value of attribute
     - parameter key: attribute name
     - returns: value for attribute
     */
    public func getAttribute(key:String) -> String? {
        return attributes_[key];
    }
    
    /**
     Removes element from children
     - parameter child: element to remove
     */
    public func removeChild(child: Element) {
        self.removeNode(child);
    }
    
    /**
     Removes node from children
     */
    public func removeNode(child: Node) {
        if let idx = self.nodes.indexOf(child) {
            self.nodes.removeAtIndex(idx);
        }
    }
    
    /// XMLNS of element
    public var xmlns:String? {
        get {
            let xmlns = attributes_["xmlns"]
            return xmlns != nil ? xmlns : defxmlns;
        }
        set {
            if (newValue == nil || newValue == defxmlns) {
                attributes_.removeValueForKey("xmlns");
            } else {
                attributes_["xmlns"] = newValue;
            }
        }
    }
    
    /**
     Set value for attribute
     - parameter key: attribute to set
     - parameter value: value to set
     */
    public func setAttribute(key:String, value:String?) {
        if (value == nil) {
            attributes_.removeValueForKey(key);
        } else {
            attributes_[key] = value;
        }
    }
    
    func setDefXMLNS(defxmlns:String?) {
        self.defxmlns = defxmlns;
    }
    
    /// String representation of element
    override public var stringValue: String {
        var result = "<\(self.name)"
        for (k,v) in attributes_ {
            let val = EscapeUtils.escape(v);
            result += " \(k)='\(val)'"
        }
        if (!nodes.isEmpty) {
            result += ">"
            for child in nodes {
                result += child.stringValue
            }
            result += "</\(self.name)>"
        } else {
            result += "/>"
        }
        return result;
        
    }
    
    override public func toPrettyString() -> String {
        var result = "<\(self.name)"
        for (k,v) in attributes_ {
            let val = EscapeUtils.escape(v);
            result += " \(k)='\(val)'"
        }
        if (!nodes.isEmpty) {
            result += ">\n"
            for child in nodes {
                let str = child.toPrettyString();
                result += str + ((child is Element && str.characters.last != "\n") ? "\n" : "")
            }
            result += "</\(self.name)>"
        } else {
            result += "/>"
        }
        return result;
    }
    
    /**
     Convenience function for parsing string with XML to create elements
     - parameter toParse: string with XML to parse
     - returns: parsed Element if any
     */
    public static func fromString(toParse: String) -> Element? {
        class Holder: XMPPStreamDelegate {
            var parsed:Element?;
            private func onError(msg: String?) {
            }
            private func onStreamStart(attributes: [String : String]) {
            }
            private func onStreamTerminate() {
            }
            private func processElement(packet: Element) {
                parsed = packet;
            }
        }
        
        var holder = Holder();
        var xmlDelegate = XMPPParserDelegate();
        xmlDelegate.delegate = holder;
        let parser = XMLParser(delegate: xmlDelegate);
        var data = toParse.dataUsingEncoding(NSUTF8StringEncoding);
        var ptr = UnsafeMutablePointer<UInt8>(data!.bytes);
        parser.parse(ptr, length: data!.length);
        return holder.parsed;
    }
}

public func ==(lhs: Element, rhs: Element) -> Bool {
    if (lhs.name != rhs.name) {
        return false;
    }
    if (lhs.attributes.count != rhs.attributes.count) {
        return false;
    }
    if (lhs.nodes.count != rhs.nodes.count) {
        return false;
    }
    for (k,v) in lhs.attributes {
        if (rhs.attributes[k] != v) {
            return false;
        }
    }
    return true;
}
