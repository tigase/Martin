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
    
    /**
     Method checks if session establishment is required
     - parameter sessionObject: instance of `SessionObject`
     - returns: true - if is required
     */
    public static func isSessionEstablishmentRequired(_ sessionObject:SessionObject) -> Bool {
        if let featuresElement = StreamFeaturesModule.getStreamFeatures(sessionObject) {
            if let session = featuresElement.findChild(name: "session", xmlns: SESSION_XMLNS) {
                return session.findChild(name: "optional") == nil;
            }
        }
        return false;
    }
    
    public var isSessionEstablishmentRequired: Bool {
        guard context?.module(.streamFeatures).streamFeatures?.findChild(name: "session", xmlns: SessionEstablishmentModule.SESSION_XMLNS)?.findChild(name: "optional") == nil else {
            return false;
        }
        return true;
    }
    
    public override init() {
        
    }
    
    /// Method should not be called due to empty `criteria`
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    /// Method called to start session establishemnt
    open func establish(completionHandler: ((Result<Void,XMPPError>)->Void)? = nil) {
        guard isSessionEstablishmentRequired else {
            if let context = context {
                fire(SessionEstablishmentSuccessEvent(context: context));
            }
            completionHandler?(.success(Void()));
            return;
        }
        let iq = Iq();
        iq.type = StanzaType.set;
        let session = Element(name:"session");
        session.xmlns = SessionEstablishmentModule.SESSION_XMLNS;
        iq.element.addChild(session);

        write(iq, completionHandler: { result in
            if let context = self.context {
                switch result {
                case .success(_):
                    self.fire(SessionEstablishmentSuccessEvent(context: context));
                case .failure(let error):
                    self.fire(SessionEstablishmentErrorEvent(context: context, error: error));
                }
            }
            completionHandler?(result.map({ _ in Void() }));
        })
    }
    
    /// Event fired when session establishment process fails
    @available(* , deprecated, message: "You should observe Context.$state instead")
    open class SessionEstablishmentErrorEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SessionEstablishmentErrorEvent();
        
        /// Error condition returned by server
        public let error: XMPPError!;
        
        fileprivate init() {
            self.error = nil;
            super.init(type: "SessionEstablishmentErrorEvent")
        }
        
        public init(context: Context, error: XMPPError) {
            self.error = error;
            super.init(type: "SessionEstablishmentErrorEvent", context: context);
        }
    }
    
    /// Event fired when session is established
    @available(* , deprecated, message: "You should observe Context.$state instead")
    open class SessionEstablishmentSuccessEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SessionEstablishmentSuccessEvent();
        
        
        fileprivate init() {
            super.init(type: "SessionEstablishmentSuccessEvent")
        }
        
        public init(context: Context) {
            super.init(type: "SessionEstablishmentSuccessEvent", context: context);
        }
    }
}
