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

class XMLParserDelegate: NSObject,NSXMLParserDelegate {
    
    var logger = Logger();
    var xmlnss = [String:String]();
    var delegate:XMPPStreamDelegate?;
    var el_stack = [Element]()
    var all_roots = [Element]()
    
    func parser(parser: NSXMLParser, foundCDATA CDATABlock: NSData) {
        var buf = Array<UInt8>(count: CDATABlock.length, repeatedValue: 0);
        CDATABlock.getBytes(&buf, length: CDATABlock.length);
        self.parser(parser, foundCharacters: NSString(bytes: &buf, length:CDATABlock.length, encoding: NSUTF8StringEncoding) as String!)
    }
    
    func parser(parser: NSXMLParser, foundCharacters string: String) {
        el_stack.last?.addNode(CData(value: string))
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if (elementName == "stream:stream") {
            delegate?.onStreamTerminate()
            return
        }
        let elem = el_stack.removeLast()
        if (el_stack.isEmpty) {
            //all_roots.append(elem)
            delegate?.processElement(elem)
        } else {
            el_stack.last?.addChild(elem);
        }
    }
    
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        logger.log("using parser", parser);
        for (k,v) in attributeDict {
            if let idx = k.characters.indexOf(":") {
                let prefix = k.substringFromIndex(idx.advancedBy(1))
                self.xmlnss[prefix] = v
            }
        }
        if (elementName == "stream:stream") {
            delegate?.onStreamStart(attributeDict)
            return
        }
        
        var xmlns:String? = namespaceURI
        if (namespaceURI == nil) {
            xmlns = attributeDict["xmlns"]
        }
        
        var attributes = attributeDict;
        var name = elementName;
        if let idx = elementName.characters.indexOf(":") {
            let prefix = elementName.substringToIndex(idx)
            if (xmlnss[prefix] != nil) {
                xmlns = xmlnss[prefix]
                attributes["xmlns:" + prefix] = nil
            }
            name = elementName.substringFromIndex(idx.advancedBy(1))
        }
        
        let elem = Element(name: name, cdata: nil, attributes: attributes)
        if (!el_stack.isEmpty) {
            let defxmlns = el_stack.last!.xmlns
            elem.setDefXMLNS(defxmlns)
        }
        if (xmlns != nil) {
            elem.xmlns = xmlns;
        }
        el_stack.append(elem);
        
        //print("starting eleent" + elementName + " with namespace: " + namespaceURI!);
        //     x += "started:" + elementName + " fqdn: " + (qName)! + "\n"
        //x += "started:" + elementName + "\n"
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError) {
        switch parseError.code {
        case NSXMLParserError.DelegateAbortedParseError.rawValue:
            log("XML parsing aborted for parser", parser)
        default:
            log("XML parsing error", parseError);
        }
    }
    
}