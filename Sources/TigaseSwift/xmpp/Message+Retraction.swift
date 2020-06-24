//
// Message+Retraction.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

extension Message {
    
    open var messageRetractionId: String? {
        get {
            guard let el = self.element.findChild(name: "apply-to", xmlns: "urn:xmpp:fasten:0"), let id = el.getAttribute("id") else {
                return nil;
            }
            guard el.findChild(name: "retract", xmlns: "urn:xmpp:message-retract:0") != nil else {
                return nil;
            }
            return id;
        }
        set {
            self.element.removeChildren(name: "apply-to", xmlns: "urn:xmpp:fasten:0");
            if let val = newValue {
                let applyTo = Element(name: "apply-to", xmlns: "urn:xmpp:fasten:0");
                applyTo.setAttribute("id", value: val);
                applyTo.addChild(Element(name: "retract", xmlns: "urn:xmpp:message-retract:0"));
                self.element.addChild(applyTo);
            }
        }
    }
    
}

extension CapabilitiesModule.AdditionalFeatures {
    
    public static let messageRetraction = CapabilitiesModule.AdditionalFeatures(rawValue: "urn:xmpp:message-retract:0");
    
}

extension Chat {
    
    open func createMessageRetraction(forMessageWithId msgId: String, fallbackBody body: String? = nil) -> Message {
        let message = Message();
        message.type = .chat;
        message.to = JID(jid);
        message.messageRetractionId = msgId;
        message.addChildren([Element(name: "fallback", xmlns: "urn:xmpp:fallback:0"), Element(name: "body", cdata: body ?? "This person attempted to retract a previous message, but it's unsupported by your client.")]);
        message.hints = [.store];
        return message;
    }

}

extension Room {
    
    open func createMessageRetraction(forMessageWithId msgId: String, fallbackBody body: String? = nil) -> Message {
        let message = Message();
        message.type = .groupchat;
        message.to = JID(jid);
        message.messageRetractionId = msgId;
        message.addChildren([Element(name: "fallback", xmlns: "urn:xmpp:fallback:0"), Element(name: "body", cdata: body ?? "This person attempted to retract a previous message, but it's unsupported by your client.")]);
        message.hints = [.store];
        return message;
    }

}

extension Channel {
    
    open func createMessageRetraction(forMessageWithId msgId: String, fallbackBody body: String? = nil) -> Message {
        let message = Message();
        message.type = .groupchat;
        message.to = JID(jid);
        message.messageRetractionId = msgId;
        message.addChildren([Element(name: "fallback", xmlns: "urn:xmpp:fallback:0"), Element(name: "body", cdata: body ?? "This person attempted to retract a previous message, but it's unsupported by your client.")]);
        message.hints = [.store];
        return message;
    }

}
