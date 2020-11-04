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
open class ResourceBinderModule: XmppModule, ContextAware, Resetable {
 
    /// Namespace used by resource binding
    static let BIND_XMLNS = "urn:ietf:params:xml:ns:xmpp-bind";
        
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = BIND_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<ResourceBinderModule>();
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    open var context:Context!;
    
    open private(set) var bindedJid: JID?;
    
    /**
     Method returns binded JID retrieved from property of `SessionObject`
     - parameter sessionObject: instance of `SessionObject` to retrieve from
     - returns: binded JID
     */
    public static func getBindedJid(_ sessionObject:SessionObject) -> JID? {
        return sessionObject.context.module(.resourceBind).bindedJid;
    }
    
    public init() {
        
    }
    
    public func reset(scope: ResetableScope) {
        if scope == .session {
            bindedJid = nil;
        }
    }
    
    /// Method called to bind resource
    open func bind() {
        let iq = Iq();
        iq.type = StanzaType.set;
        let bind = Element(name:"bind");
        bind.xmlns = ResourceBinderModule.BIND_XMLNS;
        iq.element.addChild(bind);
        let resource:String? = context.connectionConfiguration.resource;
        bind.addChild(Element(name: "resource", cdata:resource));
        context.writer?.write(iq) { (stanza:Stanza?) in
            var errorCondition:ErrorCondition?;
            if let type = stanza?.type {
                switch type {
                case .result:
                    if let name = stanza!.element.findChild(name: "bind", xmlns: ResourceBinderModule.BIND_XMLNS)?.findChild(name: "jid")?.value {
                        let jid = JID(name);
                        self.bindedJid = jid;
                        self.context.eventBus.fire(ResourceBindSuccessEvent(sessionObject: self.context.sessionObject, bindedJid: jid));
                        return;
                    }
                default:
                    if let name = stanza!.element.findChild(name: "error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            
            self.context.eventBus.fire(ResourceBindErrorEvent(sessionObject: self.context.sessionObject, errorCondition: errorCondition));
        }
            
    }
    
    /// Method should not be called due to empty `criteria` property
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request
    }
    
    /// Event fired when resource is binding fails
    open class ResourceBindErrorEvent: Event {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ResourceBindErrorEvent();
        
        public let type = "ResourceBindErrorEvent";
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
    
    /// Event fired when resource is binded
    open class ResourceBindSuccessEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ResourceBindSuccessEvent();
        
        public let type = "ResourceBindSuccessEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Full JID with binded resource
        public let bindedJid:JID!;
        
        fileprivate init() {
            self.sessionObject = nil;
            self.bindedJid = nil;
        }
        
        public init(sessionObject:SessionObject, bindedJid:JID) {
            self.sessionObject = sessionObject;
            self.bindedJid = bindedJid;
        }
    }
}
