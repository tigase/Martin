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

public class ResourceBinderModule: XmppModule, ContextAware {
 
    static let BIND_XMLNS = "urn:ietf:params:xml:ns:xmpp-bind";
    
    static let BINDED_RESOURCE_JID = "BINDED_RESOURCE_JID";
    
    public static let ID = BIND_XMLNS;
    
    public let id = BIND_XMLNS;
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    public var context:Context!;
    
    public static func getBindedJid(sessionObject:SessionObject) -> JID? {
        return sessionObject.getProperty(ResourceBinderModule.BINDED_RESOURCE_JID);
    }
    
    public init() {
        
    }
    
    public func bind() {
        let iq = Iq();
        iq.type = StanzaType.set;
        let bind = Element(name:"bind");
        bind.xmlns = ResourceBinderModule.BIND_XMLNS;
        iq.element.addChild(bind);
        let resource:String? = context.sessionObject.getProperty(SessionObject.RESOURCE);
        bind.addChild(Element(name: "resource", cdata:resource));
        context.writer?.write(iq) { (stanza:Stanza) in
            var errorCondition:ErrorCondition?;
            if let type = stanza.type {
                switch type {
                case .result:
                    if let name = stanza.element.findChild("bind", xmlns: ResourceBinderModule.BIND_XMLNS)?.findChild("jid")?.value {
                        let jid = JID(name);
                        self.context.eventBus.fire(ResourceBindSuccessEvent(sessionObject: self.context.sessionObject, bindedJid: jid));
                        return;
                    }
                default:
                if let name = stanza.element.findChild("error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            
            self.context.eventBus.fire(ResourceBindErrorEvent(sessionObject: self.context.sessionObject, errorCondition: errorCondition));
        }
            
    }
    
    public func process(elem: Stanza) throws {
        
    }
    
    public class ResourceBindErrorEvent: Event {
        
        public static let TYPE = ResourceBindErrorEvent();
        
        public let type = "ResourceBindErrorEvent";
        
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
    
    public class ResourceBindSuccessEvent: Event {
        
        public static let TYPE = ResourceBindSuccessEvent();
        
        public let type = "ResourceBindSuccessEvent";
        
        public let sessionObject:SessionObject!;
        public let bindedJid:JID!;
        
        private init() {
            self.sessionObject = nil;
            self.bindedJid = nil;
        }
        
        public init(sessionObject:SessionObject, bindedJid:JID) {
            self.sessionObject = sessionObject;
            self.bindedJid = bindedJid;
        }
    }
}