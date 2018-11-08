//
// ChatStateNotificationsModule.swift
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

open class ChatStateNotificationsModule: XmppModule, ContextAware {
    
    public static let XMLNS = "http://jabber.org/protocol/chatstates";
    
    public static let ID = XMLNS;
    
    public var id = ID;
    
    public var criteria: Criteria = Criteria.empty();
    
    public var features: [String] = [XMLNS];
    
    public func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    public var context: Context!;
    
    open func hasSupport(jid: JID) -> Bool {
        guard jid.resource != nil else {
            return hasSupport(jid: jid.bareJid);
        }
        
        guard let presenceModule: PresenceModule = context.modulesManager.getModule(PresenceModule.ID), let capsNode = presenceModule.presenceStore.getPresence(for: jid)?.capsNode else {
            return false;
        }
        
        guard let capsModule: CapabilitiesModule = context.modulesManager.getModule(CapabilitiesModule.ID) else {
            return false;
        }
        
        return capsModule.cache?.isSupported(for: capsNode, feature: ChatStateNotificationsModule.XMLNS) ?? false;
    }
    
    open func hasSupport(jid: BareJID) -> Bool {
        guard let presenceModule: PresenceModule = context.modulesManager.getModule(PresenceModule.ID) else {
            return false;
        }

        guard let presences = presenceModule.presenceStore.getPresences(for: jid), let capsModule: CapabilitiesModule = context.modulesManager.getModule(CapabilitiesModule.ID) else {
            return false;
        }
        
        let withSupport = presences.filter { (key: String, value: Presence) -> Bool in
            guard let capsNode = value.capsNode else {
                return false;
            }
            return capsModule.cache?.isSupported(for: capsNode, feature: ChatStateNotificationsModule.XMLNS) ?? false;
        }

        return !withSupport.isEmpty;
    }
    
}

public enum ChatState: String {
    case active
    case inactive
    case gone
    case composing
    case paused
    
    init?(from: String?) {
        guard from != nil else {
            return nil;
        }
        self.init(rawValue: from!);
    }
}

extension Message {
    
    var chatState: ChatState? {
        get {
            return ChatState(from: self.element.findChild(name: nil, xmlns: ChatStateNotificationsModule.XMLNS)?.name);
        }
        set {
            self.element.removeChildren { (el) -> Bool in
                return el.xmlns == ChatStateNotificationsModule.XMLNS;
            }
            if newValue != nil {
                self.element.addChild(Element(name: newValue!.rawValue, xmlns: ChatStateNotificationsModule.XMLNS));
            }
        }
    }
    
}

extension Chat {
    
    open func createMessage(_ body:String, type:StanzaType = StanzaType.chat, subject:String? = nil, chatState: ChatState?, additionalElements:[Element]? = nil) -> Message {
        let msg = self.createMessage(body, type: type, subject: subject, additionalElements: additionalElements);
        
        if (chatState != nil) {
            msg.chatState = chatState;
        }
        
        return msg;
    }
}
