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
open class ResourceBinderModule: XmppModuleBase, XmppModule, Resetable, @unchecked Sendable {
 
    /// Namespace used by resource binding
    static let BIND_XMLNS = "urn:ietf:params:xml:ns:xmpp-bind";
        
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = BIND_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<ResourceBinderModule>();
    
    public let features = [String]();
        
    public override init() {
        
    }
    
    public func reset(scopes: Set<ResetableScope>) {
    }
    
    /// Method called to bind resource
    open func bind() async throws -> JID {
        let iq = Iq(type: .set, {
            Element(name:"bind", xmlns: ResourceBinderModule.BIND_XMLNS, {
                Element(name: "resource", cdata: context?.connectionConfiguration.resource)
            })
        });
        
        let response = try await write(iq: iq);
        guard let name = response.firstChild(name: "bind", xmlns: ResourceBinderModule.BIND_XMLNS)?.firstChild(name: "jid")?.value else {
            throw XMPPError(condition: .undefined_condition, stanza: response)
        }
        
        let jid = JID(name);
        self.context?.boundJid = jid;
        return jid;
    }
    
}

// async-await support
extension ResourceBinderModule {
    
    public func bind(completionHandler: ((Result<JID,XMPPError>)->Void)? = nil) {
        Task {
            do {
                let jid = try await bind();
                completionHandler?(.success(jid))
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
}
