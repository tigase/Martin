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

extension XmppModuleIdentifier {
    public static var chatStateNotifications: XmppModuleIdentifier<ChatStateNotificationsModule> {
        return ChatStateNotificationsModule.IDENTIFIER;
    }
}

open class ChatStateNotificationsModule: XmppModuleBase, XmppModule {
    
    public static let XMLNS = "http://jabber.org/protocol/chatstates";
    
    public static let ID = XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<ChatStateNotificationsModule>();
    
    public var criteria: Criteria = Criteria.empty();
    
    public var features: [String] = [XMLNS];
    
    public func process(stanza: Stanza) throws {
        throw XMPPError(condition: .bad_request);
    }
    
    public override weak var context: Context? {
        didSet {
            if let context = self.context {
                capsModule = context.modulesManager.module(.caps);
            } else {
                capsModule = nil;
            }
        }
    }
    
    private var capsModule: CapabilitiesModule!;
    
    open func hasSupport(jid: JID) -> Bool {
        guard jid.resource != nil else {
            return hasSupport(jid: jid.bareJid);
        }
        
        return capsModule.isFeatureSupported(ChatStateNotificationsModule.XMLNS, by: jid);
    }
    
    open func hasSupport(jid: BareJID) -> Bool {
        switch capsModule.isFeatureSupported(ChatStateNotificationsModule.XMLNS, by: jid) {
        case .none:
            return false;
        default:
            return true;
        }
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
    
    open var chatState: ChatState? {
        get {
            return ChatState(from: self.element.firstChild(xmlns: ChatStateNotificationsModule.XMLNS)?.name);
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
