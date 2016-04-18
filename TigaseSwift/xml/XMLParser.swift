//
// XMLParser.swift
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

import LibXML2

struct attr {
    var name:UnsafePointer<UInt8>;
    var prefix:UnsafePointer<UInt8>;
    var attrUri:UnsafePointer<UInt8>;
    var valueBegin:UnsafePointer<UInt8>;
    var valueEnd:UnsafePointer<UInt8>;
}

struct ns {
    var prefix:UnsafePointer<UInt8>;
    var uri:UnsafePointer<UInt8>;
}

private func strFromCUtf8(ptr:UnsafePointer<Void>) -> String? {
    if ptr == nil {
        return nil;
    }
    return String(CString: UnsafePointer<CChar>(ptr), encoding: NSUTF8StringEncoding);
}

private let SAX_startElement: startElementNsSAX2Func = { ctx_, localname, prefix_, URI, nb_namespaces, namespaces_, nb_attributes, nb_defaulted, attributes_ in
    
    let parser = unsafeBitCast(ctx_, XMLParser.self);
    let name = strFromCUtf8(localname);
    let prefix = strFromCUtf8(prefix_);
    var attributes = [String:String]();
    var i=0;
    var attrsPtr = UnsafePointer<attr>(attributes_);
    while i < Int(nb_attributes) {
        var name = strFromCUtf8(attrsPtr.memory.name);
        var prefix = strFromCUtf8(attrsPtr.memory.prefix);
        var value = String(data: NSData(bytes: attrsPtr.memory.valueBegin, length: attrsPtr.memory.valueEnd-attrsPtr.memory.valueBegin), encoding: NSUTF8StringEncoding);
        if (value != nil) {
            value = EscapeUtils.unescape(value!);
        }
        if prefix == nil {
            attributes[name!] = value;
        } else {
            attributes[prefix! + ":" + name!] = value;
        }
        attrsPtr = attrsPtr.successor();
        i = i + 1;
    }
    var namespaces:[String:String]? = nil;
    if nb_namespaces > 0 {
        namespaces = [String:String]();
        var nsPtr = UnsafePointer<ns>(namespaces_);
        i = 0;
        while i < Int(nb_namespaces) {
            var prefix = strFromCUtf8(nsPtr.memory.prefix);
            var uri = strFromCUtf8(nsPtr.memory.uri);
            if prefix == nil {
                prefix = "";
            }
            if (uri != nil) {
                uri = EscapeUtils.unescape(uri!);
            }
            namespaces![prefix!] = uri;
            nsPtr = nsPtr.successor();
            i = i + 1;
        }
    }
    parser.delegate.startElement(name!, prefix: prefix, namespaces: namespaces, attributes: attributes);
    
}

private let SAX_endElement: endElementNsSAX2Func = { ctx_, localname, prefix_, URI in
    let parser = unsafeBitCast(ctx_, XMLParser.self);
    let name = strFromCUtf8(localname);
    let prefix = strFromCUtf8(prefix_);
    parser.delegate.endElement(name!, prefix: prefix);
}

private let SAX_charactersFound: charactersSAXFunc = { ctx_, chars_, len_ in
    let parser = unsafeBitCast(ctx_, XMLParser.self);
    let chars = String(data: NSData(bytes: chars_, length: Int(len_)), encoding: NSUTF8StringEncoding);
    parser.delegate.charactersFound(chars!);
}

typealias errorSAXFunc_ = @convention(c) (parsingContext: UnsafeMutablePointer<Void>, errorMessage: UnsafePointer<CChar>) -> Void;

private let SAX_error: errorSAXFunc_ = { ctx_, msg_ in
    let parser = unsafeBitCast(ctx_, XMLParser.self);
    let msg = strFromCUtf8(msg_);
    parser.delegate.error(msg!);
}

private var saxHandler = xmlSAXHandler(
    internalSubset: nil,
    isStandalone: nil,
    hasInternalSubset: nil,
    hasExternalSubset: nil,
    resolveEntity: nil,
    getEntity: nil,
    entityDecl: nil,
    notationDecl: nil,
    attributeDecl: nil,
    elementDecl: nil,
    unparsedEntityDecl: nil,
    setDocumentLocator: nil,
    startDocument: nil,
    endDocument: nil,
    startElement: nil,
    endElement: nil,
    reference: nil,
    characters: SAX_charactersFound,
    ignorableWhitespace: nil,
    processingInstruction: nil,
    comment: nil,
    warning: nil,
    error: unsafeBitCast(SAX_error, errorSAXFunc.self),
    fatalError: nil,
    getParameterEntity: nil,
    cdataBlock: nil,
    externalSubset: nil,
    initialized: XML_SAX2_MAGIC,
    _private: nil,
    startElementNs: SAX_startElement,
    endElementNs: SAX_endElement,
    serror: nil
)

public class XMLParser: Logger {
    
    private var ctx:xmlParserCtxtPtr;
    private let delegate:XMLParserDelegate;
    
    public init(delegate:XMLParserDelegate) {
        ctx = nil;
        self.delegate = delegate;
        super.init()
        ctx = xmlCreatePushParserCtxt(&saxHandler, XMLParser.bridge(self), nil, 0, nil);
    }
    
    deinit {
        xmlFreeParserCtxt(ctx);
        ctx = nil;
    }
    
    public func parse(buffer: UnsafeMutablePointer<UInt8>, length: Int) {
        log("parsing data:", length, String(data:NSData(bytes: buffer, length: length), encoding: NSUTF8StringEncoding));
        xmlParseChunk(ctx, UnsafePointer<Int8>(buffer), Int32(length), 0);
    }
    
    static func bridge<T : AnyObject>(obj : T) -> UnsafeMutablePointer<Void> {
        return UnsafeMutablePointer(Unmanaged.passUnretained(obj).toOpaque());
    }
    
    static func bridge<T : AnyObject>(ptr : UnsafeMutablePointer<Void>) -> T {
        return Unmanaged<T>.fromOpaque(COpaquePointer(ptr)).takeUnretainedValue();
    }
}

public protocol XMLParserDelegate: class {
    
    var delegate:XMPPStreamDelegate? { get set };
    
    func startElement(name:String, prefix:String?, namespaces:[String:String]?, attributes:[String:String]);
    
    func endElement(name:String, prefix:String?);
    
    func charactersFound(value:String);
    
    func error(msg:String);
    
}