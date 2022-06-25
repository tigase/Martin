//
// SessionEstablishmentModule.swift
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
    public static var sessionEstablishment: XmppModuleIdentifier<SessionEstablishmentModule> {
        return SessionEstablishmentModule.IDENTIFIER;
    }
}

/**
 Module responsible for [session establishment] process.
 
 [session establishment]: http://xmpp.org/rfcs/rfc3921.html#session
 */
open class SessionEstablishmentModule: XmppModuleBase, XmppModule {

    /// Namespace used in session establishment process
    static let SESSION_XMLNS = "urn:ietf:params:xml:ns:xmpp-session";
    
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "session";
    public static let IDENTIFIER = XmppModuleIdentifier<SessionEstablishmentModule>();
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    open override var context: Context? {
        didSet {
            store(context?.module(.streamFeatures).$streamFeatures.map({ SessionEstablishmentModule.isSessionEstablishmentRequired(streamFeatures: $0) }).assign(to: \.isSessionEstablishmentRequired, on: self));
        }
    }
    
    public static func isSessionEstablishmentRequired(streamFeatures: StreamFeatures) -> Bool {
        if let session = streamFeatures.element?.firstChild(name: "session", xmlns: SESSION_XMLNS) {
            return session.firstChild(name: "optional") == nil;
        }
        return false;
    }
    
    public private(set) var isSessionEstablishmentRequired: Bool = true;
    
    public override init() {
        
    }
    
    /// Method should not be called due to empty `criteria`
    open func process(stanza: Stanza) throws {
        throw XMPPError.bad_request(nil);
    }
    
    /// Method called to start session establishemnt
    open func establish(completionHandler: ((Result<Void,XMPPError>)->Void)? = nil) {
        guard isSessionEstablishmentRequired else {
            completionHandler?(.success(Void()));
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.set;
        let session = Element(name:"session");
        session.xmlns = SessionEstablishmentModule.SESSION_XMLNS;
        iq.element.addChild(session);

        write(iq, completionHandler: { result in
            completionHandler?(result.map({ _ in Void() }));
        })
    }
    
}

// async-await support
extension SessionEstablishmentModule {
    
    open func establish() async throws {
        _ = try await withUnsafeThrowingContinuation { continuation in
            establish(completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
}
