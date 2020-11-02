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
open class SessionEstablishmentModule: XmppModule, ContextAware {

    /// Namespace used in session establishment process
    static let SESSION_XMLNS = "urn:ietf:params:xml:ns:xmpp-session";
    
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "session";
    public static let IDENTIFIER = XmppModuleIdentifier<SessionEstablishmentModule>();
    
    open var context:Context!;
    
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
    
    public init() {
        
    }
    
    /// Method should not be called due to empty `criteria`
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    /// Method called to start session establishemnt
    open func establish() {
        let iq = Iq();
        iq.type = StanzaType.set;
        let session = Element(name:"session");
        session.xmlns = SessionEstablishmentModule.SESSION_XMLNS;
        iq.element.addChild(session);

        context.writer?.write(iq) { (stanza:Stanza?) in
            var errorCondition:ErrorCondition?;
            if let type = stanza?.type {
                switch type {
                case .result:
                    self.context.eventBus.fire(SessionEstablishmentSuccessEvent(sessionObject:self.context.sessionObject));
                    return;
                default:
                    if let name = stanza!.element.findChild(name: "error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            
            self.context.eventBus.fire(SessionEstablishmentErrorEvent(sessionObject:self.context.sessionObject, errorCondition: errorCondition));
        }
    }
    
    /// Event fired when session establishment process fails
    open class SessionEstablishmentErrorEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SessionEstablishmentErrorEvent();
        
        public let type = "SessionEstablishmentErrorEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Error condition returned by server
        public let errorCondition:ErrorCondition?;
        
        fileprivate init() {
            self.sessionObject = nil;
            self.errorCondition = nil;
        }
        
        public init(sessionObject:SessionObject, errorCondition:ErrorCondition?) {
            self.sessionObject = sessionObject;
            self.errorCondition = errorCondition;
        }
    }
    
    /// Event fired when session is established
    open class SessionEstablishmentSuccessEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SessionEstablishmentSuccessEvent();
        
        public let type = "SessionEstablishmentSuccessEvent";        
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        
        fileprivate init() {
            self.sessionObject = nil;
        }
        
        public init(sessionObject:SessionObject) {
            self.sessionObject = sessionObject;
        }
    }
}
