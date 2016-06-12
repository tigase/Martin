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

public class SessionEstablishmentModule: Logger, XmppModule, ContextAware {

    static let SESSION_XMLNS = "urn:ietf:params:xml:ns:xmpp-session";
    
    public static let ID = "session";
    
    public let id = ID;
    
    public var context:Context!;
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    public static func isSessionEstablishmentRequired(sessionObject:SessionObject) -> Bool {
        if let featuresElement = StreamFeaturesModule.getStreamFeatures(sessionObject) {
            if let session = featuresElement.findChild("session", xmlns: SESSION_XMLNS) {
                return session.findChild("optional") == nil;
            }
        }
        return false;
    }
    
    public override init() {
        
    }
    
    public func process(elem: Stanza) throws {
        
    }
    
    public func establish() {
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
                    if let name = stanza!.element.findChild("error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            
            self.context.eventBus.fire(SessionEstablishmentErrorEvent(sessionObject:self.context.sessionObject, errorCondition: errorCondition));
        }
    }
    
    public class SessionEstablishmentErrorEvent: Event {
        
        public static let TYPE = SessionEstablishmentErrorEvent();
        
        public let type = "SessionEstablishmentErrorEvent";
        
        public let sessionObject:SessionObject!;
        public let errorCondition:ErrorCondition?;
        
        private init() {
            self.sessionObject = nil;
            self.errorCondition = nil;
        }
        
        public init(sessionObject:SessionObject, errorCondition:ErrorCondition?) {
            self.sessionObject = sessionObject;
            self.errorCondition = errorCondition;
        }
    }
    
    public class SessionEstablishmentSuccessEvent: Event {
        
        public static let TYPE = SessionEstablishmentSuccessEvent();
        
        public let type = "SessionEstablishmentSuccessEvent";
        
        public let sessionObject:SessionObject!;
        
        private init() {
            self.sessionObject = nil;
        }
        
        public init(sessionObject:SessionObject) {
            self.sessionObject = sessionObject;
        }
    }
}