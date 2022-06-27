//
// ResourceBinderModule.swift
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

extension XmppModuleIdentifier {
    public static var resourceBind: XmppModuleIdentifier<ResourceBinderModule> {
        return ResourceBinderModule.IDENTIFIER;
    }
}

/**
 Module responsible for [resource binding]
 
 [resource binding]: http://xmpp.org/rfcs/rfc6120.html#bind
 */
open class ResourceBinderModule: XmppModuleBase, XmppModule, Resetable {
 
    /// Namespace used by resource binding
    static let BIND_XMLNS = "urn:ietf:params:xml:ns:xmpp-bind";
        
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = BIND_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<ResourceBinderModule>();
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    open private(set) var bindedJid: JID?;
    
    public override init() {
        
    }
    
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.session) {
            bindedJid = nil;
        }
    }
    
    /// Method called to bind resource
    open func bind(completionHandler: ((Result<JID,XMPPError>)->Void)? = nil) {
        let iq = Iq();
        iq.type = StanzaType.set;
        let bind = Element(name:"bind");
        bind.xmlns = ResourceBinderModule.BIND_XMLNS;
        iq.element.addChild(bind);
        let resource:String? = context?.connectionConfiguration.resource;
        bind.addChild(Element(name: "resource", cdata:resource));
        write(iq: iq, completionHandler: { result in
            switch result {
            case .success(let stanza):
                if let name = stanza.firstChild(name: "bind", xmlns: ResourceBinderModule.BIND_XMLNS)?.firstChild(name: "jid")?.value {
                    let jid = JID(name);
                    self.bindedJid = jid;
                    completionHandler?(.success(jid));
                } else {
                    completionHandler?(.failure(.undefined_condition));
                }
            case .failure(let error):
                completionHandler?(.failure(error));
            }
        })
    }
    
    /// Method should not be called due to empty `criteria` property
    open func process(stanza: Stanza) throws {
        throw XMPPError(condition: .bad_request);
    }
    
}

// async-await support
extension ResourceBinderModule {
    
    open func bind() async throws -> JID {
        return try await withUnsafeThrowingContinuation { continuation in
            bind(completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
}
