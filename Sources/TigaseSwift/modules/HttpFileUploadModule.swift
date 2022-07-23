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
open class HttpFileUploadModule: XmppModuleBase, XmppModule {
    
    static let HTTP_FILE_UPLOAD_XMLNS = "urn:xmpp:http:upload:0";
    
    public static let ID = HTTP_FILE_UPLOAD_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<HttpFileUploadModule>();
    
    public let features = [String]();
    
    open weak override var context: Context? {
        didSet {
            if let context = self.context {
                discoModule = context.modulesManager.module(.disco);
            } else {
                discoModule = nil;
            }
        }
    }
    
    private var discoModule: DiscoveryModule?;
    
    public override init() {
        
    }
    
    open func findHttpUploadComponents() async throws -> [HttpFileUploadModule.UploadComponent] {
        guard let disco = self.context?.module(.disco) else {
            throw XMPPError(condition: .unexpected_request, message: "No context!")
        }
        
        let components = try await disco.serverComponents().items.map({ $0.jid });
        return await withTaskGroup(of: UploadComponent?.self, body: { group in
            for componentJid in components {
                group.addTask {
                    guard let info = try? await disco.info(for: componentJid), info.features.contains(HttpFileUploadModule.HTTP_FILE_UPLOAD_XMLNS) else {
                        return nil;
                    }
                    
                    let maxSize: Int = info.form?.value(for: "max-file-size", type: Int.self) ?? Int.max;
                    return UploadComponent(jid: componentJid, maxSize: maxSize);
                }
            }
            
            var result: [UploadComponent] = [];
            for await component in group {
                if let comp = component {
                    result.append(comp);
                }
            }
            
            return result;
        });
    }
    
    open func requestUploadSlot(componentJid: JID, filename: String, size: Int, contentType: String?) async throws -> Slot {
        let iq = Iq(type: .get, to: componentJid, {
            Element(name: "request", xmlns: HttpFileUploadModule.HTTP_FILE_UPLOAD_XMLNS, {
                Attribute("filename", value: filename)
                Attribute("size", value: size.description)
                Attribute("content-type", value: contentType)
            });
        });
        
        let response = try await write(iq: iq);
        guard let slotEl = response.firstChild(name: "slot", xmlns: HttpFileUploadModule.HTTP_FILE_UPLOAD_XMLNS), let getUri = slotEl.firstChild(name: "get")?.attribute("url"), let putUri = slotEl.firstChild(name: "put")?.attribute("url") else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        
        var putHeaders: [String:String] = [:];
        for header in slotEl.firstChild(name: "put")?.filterChildren(name: "header") ?? [] {
            if let name = header.attribute("name"), let value = header.value {
                putHeaders[name] = value;
            }
        }
        
        guard let slot = Slot(getUri: getUri, putUri: putUri, putHeaders: putHeaders) else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        
        return slot;
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

// async-await support
extension HttpFileUploadModule {
    
    public func findHttpUploadComponent(completionHandler: @escaping (Result<[UploadComponent], XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await findHttpUploadComponents()));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? XMPPError(condition: .undefined_condition)));
            }
        }
    }
    
    public func requestUploadSlot(componentJid: JID, filename: String, size: Int, contentType: String?, completionHandler: @escaping (Result<Slot,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await requestUploadSlot(componentJid: componentJid, filename: filename, size: size, contentType: contentType)));
            } catch {
                completionHandler(.failure(XMPPError.undefined_condition))
            }
        }
    }

}
