//
// MixParticipant.swift
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

open class MixParticipant {
    
    public let id: String;
    public let nickname: String?;
    public let jid: BareJID?;
    
    public private(set) weak var channel: ChannelProtocol?;
    
    public convenience init?(from item: PubSubModule.Item, for channel: ChannelProtocol) {
        guard let payload = item.payload, payload.name == "participant" && payload.xmlns == MixModule.CORE_XMLNS else {
            return nil;
        }
        self.init(id: item.id, nickname: payload.findChild(name: "nick")?.value, jid: BareJID(payload.findChild(name: "jid")?.value), channel: channel);
    }
    
    public init(id: String, nickname: String?, jid: BareJID?, channel: ChannelProtocol) {
        self.id = id;
        self.nickname = nickname;
        self.jid = jid;
        self.channel = channel;
    }
    
}
