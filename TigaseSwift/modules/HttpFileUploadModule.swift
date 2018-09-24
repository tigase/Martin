//
// HttpFileUploadModule.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
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
 Module provides support for requesting upload slot at HTTP server used for 
 file transfer as specified in [XEP-0363: HTTP File Upload]
 
 [XEP-0363: HTTP File Upload]: https://xmpp.org/extensions/xep-0363.html
 */
open class HttpFileUploadModule: XmppModule, ContextAware {
    
    static let HTTP_FILE_UPLOAD_XMLNS = "urn:xmpp:http:upload:0";
    
    public static let ID = HTTP_FILE_UPLOAD_XMLNS;
    
    public let id = HTTP_FILE_UPLOAD_XMLNS;
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    open var context: Context!;
    
    public init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    open func findHttpUploadComponent(onSuccess: @escaping ([JID:Int?])->Void, onError: @escaping (ErrorCondition?)->Void) {
        guard let discoModule: DiscoveryModule = context.modulesManager.getModule(DiscoveryModule.ID) else {
            onError(ErrorCondition.undefined_condition);
            return;
        }
        
        let serverJid = JID(context.sessionObject.userBareJid!.domain)!;
        discoModule.getItems(for: serverJid, onItemsReceived: { (_, items) in
            var components: [JID:Int?] = [:];
            var queries = items.count;
            let callback = { (jid: JID?, maxFileSize: Int?) in
                DispatchQueue.main.async {
                    if (jid != nil) {
                        components[jid!] = maxFileSize;
                    }
                    queries = queries - 1;
                    if queries == 0 {
                        if components.count > 0 {
                            DispatchQueue.global().async {
                                onSuccess(components);
                            }
                        } else {
                            onError(ErrorCondition.item_not_found);
                        }
                    }
                }
            };
            items.forEach({ (item) in
                discoModule.getInfo(for: item.jid, node: nil, callback: {(stanza: Stanza?) -> Void in
                    let type = stanza?.type ?? StanzaType.error;
                    switch type {
                    case .result:
                        let query = stanza!.findChild(name: "query", xmlns: DiscoveryModule.INFO_XMLNS);
                        let features = query!.mapChildren(transform: { e -> String in
                            return e.getAttribute("var")!;
                        }, filter: { (e:Element) -> Bool in
                            return e.name == "feature" && e.getAttribute("var") != nil;
                        })
                        guard features.contains(HttpFileUploadModule.HTTP_FILE_UPLOAD_XMLNS) else {
                            callback(nil, nil);
                            return;
                        }
                        let maxFileSizeField: TextSingleField? = JabberDataElement(from: query?.findChild(name: "x", xmlns: "jabber:x:data"))?.getField(named: "max-file-size");
                        let maxFileSize = maxFileSizeField?.value != nil ? Int(maxFileSizeField!.value!) : nil;
                        callback(stanza?.from!, maxFileSize);
                    default:
                        callback(nil, nil);
                    }
                });
            });
            if queries == 0 {
                onError(ErrorCondition.item_not_found);
            }
        }, onError: onError);
    }
    
    open func requestUploadSlot(componentJid: JID, filename: String, size: Int, contentType: String?, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = componentJid;
        
        let requestEl = Element(name: "request", xmlns: HttpFileUploadModule.HTTP_FILE_UPLOAD_XMLNS);
        requestEl.setAttribute("filename", value: filename);
        requestEl.setAttribute("size", value: size.description);
        if contentType != nil {
            requestEl.setAttribute("content-type", value: contentType);
        }
        iq.addChild(requestEl);
        
        context.writer?.write(iq, callback: callback);
    }
    
    open func requestUploadSlot(componentJid: JID, filename: String, size: Int, contentType: String?, onSuccess: @escaping (Slot)->Void, onError: @escaping (ErrorCondition?,String?)->Void) {
        requestUploadSlot(componentJid: componentJid, filename: filename, size: size, contentType: contentType) { (response) in
            let type = response?.type ?? StanzaType.error;
            switch (type) {
            case .result:
                let slotEl = response?.findChild(name: "slot", xmlns: HttpFileUploadModule.HTTP_FILE_UPLOAD_XMLNS);
                let getUri = slotEl?.findChild(name: "get")?.getAttribute("url");
                let putUri = slotEl?.findChild(name: "put")?.getAttribute("url");
                var putHeaders = [String:String]();
                slotEl?.findChild(name: "put")?.forEachChild(name: "header", fn: { (header) in
                    let name = header.getAttribute("name");
                    let value = header.value;
                    if name != nil && value != nil {
                        putHeaders[name!] = value!;
                    }
                })
                if (getUri != nil && putUri != nil) {
                    onSuccess(Slot(getUri: getUri!, putUri: putUri!, putHeaders: putHeaders));
                } else {
                    onError(ErrorCondition.undefined_condition, nil);
                }
            default:
                onError(response?.errorCondition, response?.errorText);
            }
        }
    }
    
    open class Slot {
        
        public let getUri: String;
        public let putUri: String;
        public let putHeaders: [String: String];
        
        public init(getUri: String, putUri: String, putHeaders: [String:String]) {
            self.getUri = getUri;
            self.putUri = putUri;
            self.putHeaders = putHeaders;
        }
        
    }
}
