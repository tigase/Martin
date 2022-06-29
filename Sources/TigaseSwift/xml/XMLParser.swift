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

import libxml2

struct attr {
    var name:UnsafePointer<UInt8>?;
    var prefix:UnsafePointer<UInt8>?;
    var attrUri:UnsafePointer<UInt8>?;
    var valueBegin:UnsafePointer<UInt8>?;
    var valueEnd:UnsafePointer<UInt8>?;
}

struct ns {
    var prefix:UnsafePointer<UInt8>?;
    var uri:UnsafePointer<UInt8>?;
}

private func strFromCUtf8(_ ptr:UnsafePointer<UInt8>?) -> String? {
    if ptr == nil {
        return nil;
    }
    return String(cString: ptr!);
}

private let SAX_startElement: startElementNsSAX2Func = { ctx_, localname, prefix_, URI, nb_namespaces, namespaces_, nb_attributes, nb_defaulted, attributes_ in
    
    let attributesCount = Int(nb_attributes);
    let parser = unsafeBitCast(ctx_, to: XMLParser.self);
    let name = strFromCUtf8(localname);
    let prefix = strFromCUtf8(prefix_);
    var attributes = [String:String]();
    var i=0;
    if let attributes_ = attributes_ {
        attributes_.withMemoryRebound(to: attr.self, capacity: attributesCount) {
            var attrsPtr = $0;
            for i in 0..<attributesCount {
                let name = strFromCUtf8(attrsPtr.pointee.name)!;
                let value = String(data: Data(bytes: UnsafePointer<UInt8>((attrsPtr.pointee.valueBegin)!), count: (attrsPtr.pointee.valueEnd)!-(attrsPtr.pointee.valueBegin)!), encoding: String.Encoding.utf8)?.xmlUnescaped();
                if let prefix = strFromCUtf8(attrsPtr.pointee.prefix) {
                    attributes["\(prefix):\(name)"] = value;
                } else {
                    attributes[name] = value;
                }
                attrsPtr = attrsPtr.successor();
            }
        }
    }
    
    var namespaces:[String:String]? = nil;
    if nb_namespaces > 0 {
        namespaces = [String:String]();
        namespaces_!.withMemoryRebound(to: ns.self, capacity: Int(nb_namespaces)) {
            var nsPtr = $0;
            for i in 0..<Int(nb_namespaces) {
                let prefix = strFromCUtf8(nsPtr.pointee.prefix) ?? "";
                let uri = strFromCUtf8(nsPtr.pointee.uri)?.xmlUnescaped();
                namespaces![prefix] = uri;
                nsPtr = nsPtr.successor();
            }
        }
    }
    parser.delegate.startElement(name: name!, prefix: prefix, namespaces: namespaces, attributes: attributes);
    
}

private let SAX_endElement: endElementNsSAX2Func = { ctx_, localname, prefix_, URI in
    let parser = unsafeBitCast(ctx_, to: XMLParser.self);
    let name = strFromCUtf8(localname);
    let prefix = strFromCUtf8(prefix_);
    parser.delegate.endElement(name: name!, prefix: prefix);
}

private let SAX_charactersFound: charactersSAXFunc = { ctx_, chars_, len_ in
    let parser = unsafeBitCast(ctx_, to: XMLParser.self);
    let chars = strFromCUtf8(chars_);
    parser.delegate.charactersFound(chars!);
}

//typealias errorSAXFunc_ = @convention(c) (_ parsingContext: UnsafeMutableRawPointer, _ errorMessage: UnsafePointer<CChar>, _ parameter: UnsafePointer<CChar>?) -> Void;
//
//private let SAX_error: errorSAXFunc_ = { ctx_, msg_, parameter_ in
//    let parser = unsafeBitCast(ctx_, to: XMLParser.self);
//    let msg = String(cString: msg_, encoding: String.Encoding.utf8)! + ", " + String(cString: parameter_!, encoding: String.Encoding.utf8)!
//    parser.delegate.error(msg: msg);
//}

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
    error: nil,//unsafeBitCast(SAX_error, to: errorSAXFunc.self),
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

/**
 Wrapper class for LibXML2 to make it easier to use from Swift
 */
open class XMLParser {
    
    fileprivate var ctx:xmlParserCtxtPtr?;
    fileprivate let delegate:XMLParserDelegate;
    
    /**
     Create XMLParser
     - parameter delegate: delagate which will be called during parsing of data
     */
    public init(delegate:XMLParserDelegate) {
        ctx = nil;
        self.delegate = delegate;
        ctx = xmlCreatePushParserCtxt(&saxHandler, XMLParser.bridge(self), nil, 0, nil);
    }
    
    deinit {
        xmlFreeParserCtxt(ctx);
        ctx = nil;
    }
    
    /**
     Parses data passed as parameters and returns result by calling proper 
     delegates functions
     - parameter buffer: pointer to data
     - parameter length: number of data to process
     */
    open func parse(bytes buffer: UnsafeMutablePointer<UInt8>, length: Int) {
        _ = buffer.withMemoryRebound(to: CChar.self, capacity: length) {
            xmlParseChunk(ctx, $0, Int32(length), 0);
        }
    }

    /**
     Parses data passed as parameters and returns result by calling proper
     delegates functions
     - parameter data: instance of Data to process
     */
    open func parse(data: Data) throws {
//        log("parsing data:", data.count, String(data: data, encoding: String.Encoding.utf8));
        try data.withUnsafeBytes { (ptr) -> Void in
            let err = xmlParseChunk(ctx, ptr.baseAddress!.assumingMemoryBound(to: CChar.self), Int32(data.count), 0);
            if err > 0 {
                if err == 64 {
                    if let position = data.range(of: "<?xml ".data(using: .utf8)!)?.lowerBound {
                        throw XmlParserError.xmlDeclarationInside(Int(err), position);
                    }
                }
                throw XmlParserError.unknown(Int(err))
            }
        }
    }
    
    static func bridge<T : AnyObject>(_ obj : T) -> UnsafeMutableRawPointer {
        return Unmanaged.passUnretained(obj).toOpaque();
    }
    
    static func bridge<T : AnyObject>(_ ptr : UnsafeMutableRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue();
    }
}

public enum XmlParserError: Error {
    case unknown(Int)
    case xmlDeclarationInside(Int, Int)
    
    var code: Int {
        switch self {
        case .unknown(let codeInt):
            return codeInt;
        case .xmlDeclarationInside(let codeInt, _):
            return codeInt;
        }
    }
    
    var position: Int? {
        switch self {
        case .xmlDeclarationInside( _, let position):
            return position;
        default:
            return nil;
        }
    }
}

/**
 Protocol needs to be implemented by classes responsible for handling 
 data during parsing of XML by `XMLParser`
 */
public protocol XMLParserDelegate: AnyObject {
        
    /**
     Called when start of element is found
     - parameter name: name of element
     - parameter prefix: prefix of element
     - parameter namespaces: declared namespaces
     - parameter attributes: attributes of element
     */
    func startElement(name:String, prefix:String?, namespaces:[String:String]?, attributes:[String:String]);
    
    /**
     Called when element end is found
     - parameter name: name of element
     - parameter prefix: prefix of element
     */
    func endElement(name:String, prefix:String?);
    
    /**
     Called when characters are found inside element
     - parameter value: found characters
     */
    func charactersFound(_ value:String);
        
}
