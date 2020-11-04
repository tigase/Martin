//
// PushNotificationModule.swift
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
    public static var push: XmppModuleIdentifier<PushNotificationsModule> {
        return PushNotificationsModule.IDENTIFIER;
    }
}

open class PushNotificationsModule: XmppModule, ContextAware {
    
    public static let PUSH_NOTIFICATIONS_XMLNS = "urn:xmpp:push:0";
    
    public static let ID = PUSH_NOTIFICATIONS_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<PushNotificationsModule>();
    
    public let criteria = Criteria.name("message").add(Criteria.name("pubsub", xmlns: PubSubModule.PUBSUB_XMLNS).add(Criteria.name("affiliation")));
    
    public let features = [String]();
    
    open var context:Context!;
    
    open var isAvailable: Bool {
        if let features: [String] = context.module(.disco).accountDiscoResult?.features {
            if features.contains(PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS) {
                return true;
            }
        }
        
        // TODO: fallback to handle previous behavior - remove it later on...
        if let features: [String] = context.module(.disco).serverDiscoResult?.features {
            if features.contains(PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS) {
                return true;
            }
        }
        
        return false;
    }
    
    open func isSupported(extension type: PushNotificationsModuleExtension.Type) -> Bool {
        if let features: [String] = context.module(.disco).accountDiscoResult?.features {
            return features.contains(type.XMLNS);
        }
        return false;
    }
    
    open func isSupported(feature: String) -> Bool {
        if let features: [String] = context.module(.disco).accountDiscoResult?.features {
            return features.contains(feature);
        }
        return false;
    }
//    open var pushServiceJid: JID?;
    
    public init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        guard let from = stanza.from, let pubsubEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS) else {
            return;
        }
        guard let affiliationEl = pubsubEl.findChild(name: "affiliation"), let node = pubsubEl.getAttribute("node") else {
            return;
        }
        guard let jid = BareJID(affiliationEl.getAttribute("jid")), let affiliation = affiliationEl.getAttribute("affiliation") else {
            return;
        }
        guard jid == context.userBareJid && affiliation == "none" else {
            return;
        }
        
        context.eventBus.fire(NotificationsDisabledEvent(sessionObject: context.sessionObject, service: from, node: node));
    }
    
    open func enable(serviceJid: JID, node: String, extensions: [PushNotificationsModuleExtension] = [], publishOptions: JabberDataElement? = nil, completionHandler: @escaping (Result<Stanza,ErrorCondition>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        let enable = Element(name: "enable", xmlns: PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS);
        enable.setAttribute("jid", value: serviceJid.stringValue);
        enable.setAttribute("node", value: node);
        for ext in extensions {
            ext.apply(to: enable);
        }
        if publishOptions != nil {
            enable.addChild(publishOptions!.submitableElement(type: .submit));
        }
        iq.addChild(enable);
        context.writer?.write(iq) { (stanza: Stanza?) in
            var errorCondition:ErrorCondition?;
            if let type = stanza?.type {
                switch type {
                case .result:
                    completionHandler(.success(stanza!));
                    return;
                default:
                    if let name = stanza!.element.findChild(name: "error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            completionHandler(.failure(errorCondition ?? .undefined_condition));
        }
    }
    
    open func disable(serviceJid: JID, node: String, completionHandler: ((Result<Stanza,ErrorCondition>)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        let disable = Element(name: "disable", xmlns: PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS);
        disable.setAttribute("jid", value: serviceJid.stringValue);
        disable.setAttribute("node", value: node);
        iq.addChild(disable);
        
        context.writer?.write(iq) { (stanza: Stanza?) in
            var errorCondition:ErrorCondition?;
            if let type = stanza?.type {
                switch type {
                case .result:
                    completionHandler?(.success(stanza!));
                    return;
                default:
                    if let name = stanza!.element.findChild(name: "error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            completionHandler?(.failure(errorCondition ?? .undefined_condition));
        }
    }
    
    open class NotificationsDisabledEvent : Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = NotificationsDisabledEvent();
        
        public let type = "PushNotificationsDisabledEvent"
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// JID of disabled service
        public let serviceJid: JID!;
        /// Node of disable service
        public let serviceNode: String!;
        
        
        init() {
            self.sessionObject = nil;
            self.serviceJid = nil;
            self.serviceNode = nil;
        }
        
        init(sessionObject: SessionObject, service pushServiceJid: JID, node: String ) {
            self.sessionObject = sessionObject;
            self.serviceJid = pushServiceJid;
            self.serviceNode = node;
        }
    }
    
}

public protocol PushNotificationsModuleExtension {
    
    static var XMLNS: String { get }
 
    func apply(to enableEl: Element);

    func hash(into hasher: inout Hasher);
}

extension PushNotificationsModuleExtension {

    static func isSupported(features: [String]) -> Bool {
        return features.contains(XMLNS);
    }
    
}
