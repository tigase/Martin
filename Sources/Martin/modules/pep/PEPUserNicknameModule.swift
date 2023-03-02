//
// PEPUserNicknameModule.swift
//
// Martin
// Copyright (C) 2023 "Tigase, Inc." <office@tigase.com>
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
import Combine

extension XmppModuleIdentifier {
    public static var pepUserNickname: XmppModuleIdentifier<PEPUserNicknameModule> {
        return PEPUserNicknameModule.IDENTIFIER;
    }
}

open class PEPUserNicknameModule: AbstractPEPModule, XmppModule {

    public static let XMLNS = "http://jabber.org/protocol/nick";
    
    public static let ID = XMLNS
    public static let IDENTIFIER = XmppModuleIdentifier<PEPUserNicknameModule>();
    
    public let features: [String] = [XMLNS + "+notify"];

    public let nicknameChangePublisher = PassthroughSubject<Nickname,Never>();
    
    public override init() {
    }
    
    open func publish(nick: String) async throws -> String {
        return try await pubsubModule.publishItem(at: nil, to: PEPUserNicknameModule.XMLNS, payload: Element(name: "nick", xmlns: PEPUserNicknameModule.XMLNS, cdata: nick));
    }
    
    open func retrieveNick(from jid: BareJID, itemId: String? = nil) async throws -> Nickname {
        let result = try await pubsubModule.retrieveItems(from: jid, for: PEPUserNicknameModule.XMLNS, limit: itemId != nil ? .items(withIds: [itemId!]) : .lastItems(1));
        guard let item = result.items.first else { throw XMPPError(condition: .item_not_found) };
        
        return .init(jid: jid.jid(), itemId: item.id, nick: nickname(fromPayload: item.payload));
    }
        
    open override func onItemNotification(notification: PubSubModule.ItemNotification) {
        guard notification.node == PEPUserNicknameModule.XMLNS, let context = self.context else {
            return;
        }
        
        switch notification.action {
        case .published(let item):
            nicknameChangePublisher.send(.init(jid: notification.message.from ?? context.userBareJid.jid(), itemId: item.id, nick: nickname(fromPayload: item.payload)));
        case .retracted(_):
            break;
        }
    }
    
    open func nickname(fromPayload: Element?) -> String? {
        guard let payload = fromPayload, payload.name == "nick" && payload.xmlns == PEPUserNicknameModule.XMLNS else {
            return nil;
        }
        
        return payload.value;
    }
    
    public struct Nickname {
        public let jid: JID;
        public let itemId: String;
        public let nick: String?;
        
        public init(jid: JID, itemId: String, nick: String?) {
            self.jid = jid;
            self.itemId = itemId;
            self.nick = nick;
        }
        
    }

}
