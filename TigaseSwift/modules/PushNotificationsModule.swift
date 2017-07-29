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

open class PushNotificationsModule: XmppModule, ContextAware {
    
    open static let PUSH_NOTIFICATIONS_XMLNS = "urn:xmpp:push:0";
    
    open static let ID = PUSH_NOTIFICATIONS_XMLNS;
    
    open let id = PUSH_NOTIFICATIONS_XMLNS;
    
    open let criteria = Criteria.name("message").add(Criteria.name("pubsub", xmlns: PubSubModule.PUBSUB_XMLNS).add(Criteria.name("affiliation")));
    
    open let features = [String]();
    
    open var context:Context!;
    
    open var isAvailable: Bool {
        if let features: [String] = context.sessionObject.getProperty(DiscoveryModule.SERVER_FEATURES_KEY) {
            return features.contains(PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS);
        }
        return false;
    }
    
    open var pushServiceJid: JID?;
    
    public init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        guard pushServiceJid != nil && stanza.from != nil && pushServiceJid! == stanza.from! else {
            return;
        }
        guard let pubsubEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS) else {
            return;
        }
        guard let affiliationEl = pubsubEl.findChild(name: "affiliation"), let node = pubsubEl.getAttribute("node") else {
            return;
        }
        guard let jid = BareJID(affiliationEl.getAttribute("jid")), let affiliation = affiliationEl.getAttribute("affiliation") else {
            return;
        }
        guard jid == context.sessionObject.userBareJid && affiliation == "none" else {
            return;
        }
        
        context.eventBus.fire(NotificationsDisabledEvent(sessionObject: context.sessionObject, service: pushServiceJid!, node: node));
    }
    
    open func enable(serviceJid: JID, node: String, enableForAway: Bool = false, publishOptions: JabberDataElement? = nil, onSuccess: @escaping (Stanza)->Void, onError: @escaping (ErrorCondition?)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        let enable = Element(name: "enable", xmlns: PushNotificationsModule.PUSH_NOTIFICATIONS_XMLNS);
        enable.setAttribute("jid", value: serviceJid.stringValue);
        enable.setAttribute("node", value: node);
        if enableForAway {
            enable.setAttribute("away", value: "true");
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
                    onSuccess(stanza!);
                    return;
                default:
                    if let name = stanza!.element.findChild(name: "error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            onError(errorCondition);
        }
    }
    
    open func disable(serviceJid: JID, node: String, onSuccess: @escaping (Stanza)->Void, onError: @escaping (ErrorCondition?)->Void) {
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
                    onSuccess(stanza!);
                    return;
                default:
                    if let name = stanza!.element.findChild(name: "error")?.firstChild()?.name {
                        errorCondition = ErrorCondition(rawValue: name);
                    }
                }
            }
            onError(errorCondition);
        }
    }
    
    open func registerDevice(serviceJid: JID, provider: String, deviceId: String, onSuccess: @escaping (String)->Void, onError: @escaping (ErrorCondition?)->Void) {
        guard let adhocModule: AdHocCommandsModule = context.modulesManager.getModule(AdHocCommandsModule.ID) else {
            onError(ErrorCondition.undefined_condition);
            return;
        }
        
        let data = JabberDataElement(type: .submit);
        data.addField(TextSingleField(name: "provider", value: provider));
        data.addField(TextSingleField(name: "device-token", value: deviceId));
        
        adhocModule.execute(on: serviceJid, command: "register-device", action: .execute, data: data, onSuccess: { (stanza, resultData) in
            guard let node = (resultData?.getField(named: "node") as? TextSingleField)?.value else {
                onError(ErrorCondition.undefined_condition);
                return;
            }
            onSuccess(node);
        }, onError: onError);
    }
    
    open func unregisterDevice(serviceJid: JID, provider: String, deviceId: String, onSuccess: @escaping ()->Void, onError: @escaping (ErrorCondition?)->Void) {
        guard let adhocModule: AdHocCommandsModule = context.modulesManager.getModule(AdHocCommandsModule.ID) else {
            onError(ErrorCondition.undefined_condition);
            return;
        }
        
        let data = JabberDataElement(type: .submit);
        data.addField(TextSingleField(name: "provider", value: provider));
        data.addField(TextSingleField(name: "device-token", value: deviceId));
        
        adhocModule.execute(on: serviceJid, command: "unregister-device", action: .execute, data: data, onSuccess: { (stanza, resultData) in
            onSuccess();
        }, onError: onError);
    }
    
    open class NotificationsDisabledEvent : Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = NotificationsDisabledEvent();
        
        open let type = "PushNotificationsDisabledEvent"
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// JID of disabled service
        open let serviceJid: JID!;
        /// Node of disable service
        open let serviceNode: String!;
        
        
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
