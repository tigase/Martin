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

extension XmppModuleIdentifier {
    public static var httpFileUpload: XmppModuleIdentifier<HttpFileUploadModule> {
        return HttpFileUploadModule.IDENTIFIER;
    }
}

/**
 Module provides support for requesting upload slot at HTTP server used for 
 file transfer as specified in [XEP-0363: HTTP File Upload]
 
 [XEP-0363: HTTP File Upload]: https://xmpp.org/extensions/xep-0363.html
 */
open class HttpFileUploadModule: XmppModule, ContextAware {
    
    static let HTTP_FILE_UPLOAD_XMLNS = "urn:xmpp:http:upload:0";
    
    public static let ID = HTTP_FILE_UPLOAD_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<HttpFileUploadModule>();
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    open var context: Context! {
        didSet {
            if let context = self.context {
                discoModule = context.modulesManager.module(.disco);
            } else {
                discoModule = nil;
            }
        }
    }
    
    private var discoModule: DiscoveryModule!;
    
    public init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    open func findHttpUploadComponent(completionHandler: @escaping (Result<[UploadComponent], ErrorCondition>)->Void) {
        let serverJid = JID(context.userBareJid.domain);
        discoModule.getItems(for: serverJid, completionHandler: { result in
            switch result {
            case .failure(let errorCondition, _):
                completionHandler(.failure(errorCondition));
            case .success(_, let items):
                var results: [UploadComponent] = [];
                let group = DispatchGroup();
                
                group.notify(queue: DispatchQueue.main, execute: {
                    guard !results.isEmpty else {
                        completionHandler(.failure(.item_not_found));
                        return;
                    }
                    completionHandler(.success(results));
                })
                
                group.enter();
                for item in items {
                    group.enter();
                    self.discoModule.getInfo(for: item.jid, node: nil, completionHandler: { result in
                        switch result {
                        case .failure(_, _):
                            break;
                        case .success(_, _, let features, let form):
                            if features.contains(HttpFileUploadModule.HTTP_FILE_UPLOAD_XMLNS) {
                                DispatchQueue.main.async {
                                    let maxSizeField: TextSingleField? = form?.getField(named: "max-file-size");
                                    let maxSize = Int(maxSizeField?.value ?? "") ?? Int.max;
                                    results.append(UploadComponent(jid: item.jid, maxSize: maxSize));
                                }
                            }
                        }
                        group.leave();
                    });
                }
                group.leave();
            }
        });
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
    
    open func requestUploadSlot(componentJid: JID, filename: String, size: Int, contentType: String?, completionHandler: @escaping (Result<Slot,ErrorCondition>)->Void) {
        requestUploadSlot(componentJid: componentJid, filename: filename, size: size, contentType: contentType, callback: { (stanza) in
            if let response = stanza, response.type == .result {
                guard let slotEl = response.findChild(name: "slot", xmlns: HttpFileUploadModule.HTTP_FILE_UPLOAD_XMLNS), let getUri = slotEl.findChild(name: "get")?.getAttribute("url"), let putUri = slotEl.findChild(name: "put")?.getAttribute("url") else {
                    completionHandler(.failure(.undefined_condition));
                    return;
                }
                
                var putHeaders: [String:String] = [:];
                slotEl.findChild(name: "put")?.forEachChild(name: "header", fn: { (header) in
                    let name = header.getAttribute("name");
                    let value = header.value;
                    if name != nil && value != nil {
                        putHeaders[name!] = value!;
                    }
                })
                
                if let slot = Slot(getUri: getUri, putUri: putUri, putHeaders: putHeaders) {
                    completionHandler(.success(slot));
                } else {
                    completionHandler(.failure(.undefined_condition));
                }
            } else {
                completionHandler(.failure(stanza?.errorCondition ?? .remote_server_timeout));
            }
        });
    }
    
    public struct UploadComponent {
        public let jid: JID;
        public let maxSize: Int;
    }
    
    open class Slot {
        
        public let getUri: URL;
        public let putUri: URL;
        public let putHeaders: [String: String];
        
        public convenience init?(getUri getUriStr: String, putUri putUriStr: String, putHeaders: [String:String]) {
            guard let getUri = URL(string: getUriStr.replacingOccurrences(of: " ", with: "%20")), let putUri = URL(string: putUriStr.replacingOccurrences(of: " ", with: "%20")) else {
                return nil;
            }
            self.init(getUri: getUri, putUri: putUri, putHeaders: putHeaders);
        }
        
        public init(getUri: URL, putUri: URL, putHeaders: [String:String]) {
            self.getUri = getUri;
            self.putUri = putUri;
            self.putHeaders = putHeaders;
        }
        
    }
}
