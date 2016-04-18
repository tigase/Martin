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

public class Element : Node {
    public var name:String!
    var defxmlns:String?
    private var attributes:[String:String];
    private var nodes = Array<Node>()
    
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
    
    public init(name: String, cdata: String? = nil, attributes: [String:String] = [String:String]()) {
        self.name = name;
        if (cdata != nil) {
            self.nodes.append(CData(value: cdata!));
        }
        self.attributes = attributes;
    }
    
    public func addChild(child: Element) {
        self.addNode(child)
    }
    
    func addNode(child:Node) {
        self.nodes.append(child)
    }
    
    func findChild(name:String? = nil, xmlns:String? = nil) -> Element? {
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
    
    func firstChild() -> Element? {
        for node in nodes {
            if (node is Element) {
                return node as? Element;
            }
        }
        return nil;
    }
    
    func forEachChild(name:String? = nil, xmlns:String? = nil, fn: (Element)->Void) {
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
    
    func getChildren(name:String? = nil, xmlns:String? = nil) -> Array<Element> {
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
    
    public func getAttribute(key:String) -> String? {
        return attributes[key];
    }
    
    public func removeChild(child: Element) {
        self.removeNode(child);
    }
    
    public func removeNode(child: Node) {
        if let idx = self.nodes.indexOf(child) {
            self.nodes.removeAtIndex(idx);
        }
    }
    
    public var xmlns:String? {
        get {
            let xmlns = attributes["xmlns"]
            return xmlns != nil ? xmlns : defxmlns;
        }
        set {
            if (newValue == nil || newValue == defxmlns) {
                attributes.removeValueForKey("xmlns");
            } else {
                attributes["xmlns"] = newValue;
            }
        }
    }
    
    func setAttribute(key:String, value:String?) {
        if (value == nil) {
            attributes.removeValueForKey(key);
        } else {
            attributes[key] = value;
        }
    }
    
    func setDefXMLNS(defxmlns:String?) {
        self.defxmlns = defxmlns;
    }
    
    override public var stringValue: String {
        var result = "<\(self.name)"
        for (k,v) in attributes {
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
        for (k,v) in attributes {
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
