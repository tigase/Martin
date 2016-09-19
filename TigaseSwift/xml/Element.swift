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
open class Element : Node, ElementProtocol {
    /// Element name
    open let name:String
    var defxmlns:String?
    fileprivate var attributes_:[String:String];
    fileprivate var nodes = Array<Node>()
    
    /// Attributes of XML element
    open var attributes:[String:String] {
        get {
            return self.attributes_;
        }
    }
    
    /// Check if element contains subelements
    open var hasChildren:Bool {
        return !nodes.isEmpty && !getChildren().isEmpty;
    }
    
    /// Value of cdata of this element
    open var value:String? {
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
    open func addChild(_ child: Element) {
        self.addNode(child)
    }
    
    /**
     Add subelements
     - parameter children: array of elements to add as subelements
     */
    open func addChildren(_ children: [Element]) {
        children.forEach { (c) in
            self.addChild(c);
        }
    }
    
    func addNode(_ child:Node) {
        self.nodes.append(child)
    }
    
    /**
     In subelements finds element with matching name and/or xmlns and returns it
     - parameter name: name of element to find
     - parameter xmlns: xmlns of element to find
     - returns: first element which name and xmlns matches
     */
    open func findChild(_ name:String? = nil, xmlns:String? = nil) -> Element? {
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
    open func firstChild() -> Element? {
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
    open func forEachChild(_ name:String? = nil, xmlns:String? = nil, fn: (Element)->Void) {
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
    open func mapChildren<U>(_ transform: (Element) -> U?, filter: ((Element) -> Bool)? = nil) -> [U] {
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
    open func getChildren(_ name:String? = nil, xmlns:String? = nil) -> Array<Element> {
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
    open func getAttribute(_ key:String) -> String? {
        return attributes_[key];
    }
    
    /**
     Removes element from children
     - parameter child: element to remove
     */
    open func removeChild(_ child: Element) {
        self.removeNode(child);
    }
    
    /**
     Removes node from children
     */
    open func removeNode(_ child: Node) {
        if let idx = self.nodes.index(of: child) {
            self.nodes.remove(at: idx);
        }
    }
    
    /// XMLNS of element
    open var xmlns:String? {
        get {
            let xmlns = attributes_["xmlns"]
            return xmlns != nil ? xmlns : defxmlns;
        }
        set {
            if (newValue == nil || newValue == defxmlns) {
                attributes_.removeValue(forKey: "xmlns");
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
    open func setAttribute(_ key:String, value:String?) {
        if (value == nil) {
            attributes_.removeValue(forKey: key);
        } else {
            attributes_[key] = value;
        }
    }
    
    func setDefXMLNS(_ defxmlns:String?) {
        self.defxmlns = defxmlns;
    }
    
    /// String representation of element
    override open var stringValue: String {
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
    
    override open func toPrettyString() -> String {
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
    open static func fromString(_ toParse: String) -> Element? {
        class Holder: XMPPStreamDelegate {
            var parsed:Element?;
            fileprivate func onError(_ msg: String?) {
            }
            fileprivate func onStreamStart(_ attributes: [String : String]) {
            }
            fileprivate func onStreamTerminate() {
            }
            fileprivate func processElement(_ packet: Element) {
                parsed = packet;
            }
        }
        
        let holder = Holder();
        let xmlDelegate = XMPPParserDelegate();
        xmlDelegate.delegate = holder;
        let parser = XMLParser(delegate: xmlDelegate);
        var data = toParse.data(using: String.Encoding.utf8);
        let ptr = UnsafeMutablePointer<UInt8>(mutating: (data! as NSData).bytes.bindMemory(to: UInt8.self, capacity: data!.count));
        parser.parse(ptr, length: data!.count);
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
