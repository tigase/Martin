//
// XMPPParserDelegate.swift
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

public protocol XMPPParserDelegateDelegate: AnyObject {
    
    func parsed(parserEvent: XMPPParserEvent)
    
}

public enum XMPPParserEvent {
    case streamOpened([String:String])
    case streamClosed
    case error
    case element(Element)
}
 
/**
 Implementation of XMLParserDelegate to properly parse XMPP stream
 and notify about stream start and end.
 */
open class XMPPParserDelegate: XMLParserDelegate {
    
    private var xmlnss = [String:String]();
    open weak var delegate: XMPPParserDelegateDelegate?;
    private var el_stack = [Element]()
    private var all_roots = [Element]()
    
    public var parsed: [Element] {
        return all_roots;
    }
    
    public init() {
    }
    
    open func startElement(name elementName: String, prefix: String?, namespaces: [String:String]?, attributes: [String:String]) {
        
        if let namespaces = namespaces {
            for (k,v) in namespaces {
                if !k.isEmpty {
                    xmlnss[k] = v;
                }
            }
        }
        
        guard elementName != "stream" || prefix != "stream" else {
            var attrs = attributes;
            if let namespaces = namespaces {
                for (k,v) in namespaces {
                    attrs[k] = v;
                }
            }
            self.delegate?.parsed(parserEvent: .streamOpened(attrs));
            return
        }
        
        let xmlns:String? = (prefix == nil ? nil : xmlnss[prefix!]) ?? namespaces?[""];
        
        let name = (prefix != nil && xmlns == nil) ? "\(prefix!):\(elementName)" : elementName;
        
        let elem = Element(name: name, cdata: nil, attributes: attributes)
        if (!el_stack.isEmpty) {
            let defxmlns = el_stack.last!.xmlns
            elem.setDefXMLNS(defxmlns)
        }
        if (xmlns != nil) {
            elem.xmlns = xmlns;
        }
        el_stack.append(elem);
    }
    
    open func endElement(name elementName: String, prefix: String?) {
        guard elementName != "stream" || prefix != "stream" else {
            self.delegate?.parsed(parserEvent: .streamClosed);
            return
        }
        
        let elem = el_stack.removeLast()
        if (el_stack.isEmpty) {
            if let delegate = self.delegate {
                delegate.parsed(parserEvent: .element(elem));
            } else {
                all_roots.append(elem)
            }
        } else {
            el_stack.last?.addChild(elem);
        }
    }
    
    open func charactersFound(_ value: String) {
        el_stack.last?.addNode(.cdata(value))
    }
        
}
