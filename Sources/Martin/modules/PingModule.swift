//
// PingModule.swift
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
    public static var ping: XmppModuleIdentifier<PingModule> {
        return PingModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0199: XMPP Ping]
 
 [XEP-0199: XMPP Ping]: http://xmpp.org/extensions/xep-0199.html
 */
open class PingModule: XmppModuleBase, AbstractIQModule, @unchecked Sendable {
    /// Namespace used by XMPP ping
    fileprivate static let PING_XMLNS = "urn:xmpp:ping";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = PING_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<PingModule>();
    
    public let criteria = Criteria.name("iq").add(Criteria.name("ping", xmlns: PING_XMLNS));
    
    public let features = [PING_XMLNS];
    
    public override init() {
        
    }
    
    /**
     Send ping request to jid
     - parameter jid: ping destination
     - parameter timeout: timeout for ping response
     */
    open func ping(_ jid: JID, timeout: TimeInterval = 120.0) async throws {
        let iq = Iq(type: .get, to: jid);
        iq.addChild(Element(name: "ping", xmlns: PingModule.PING_XMLNS));
        
        do {
            try await write(iq: iq, timeout: timeout);
        } catch {
            if let err = error as? XMPPError, err.condition == .feature_not_implemented {
                return;
            }
            throw error;
        }
    }
    
    /**
     Processes ping requests and responds properly
     */
    open func processGet(stanza: Stanza) throws {
        let result = stanza.makeResult(type: .result);
        write(stanza: result);
    }
    
    open func processSet(stanza: Stanza) throws {
        throw XMPPError(condition: .bad_request);
    }
}

// async-await support
extension PingModule {
    
    public func ping(_ jid: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await ping(jid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
}
