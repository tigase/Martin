//
// ChannelBase.swift
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

open class ChannelBase: ConversationBase, ChannelProtocol {
        
    open override var defaultMessageType: StanzaType {
        return .groupchat;
    }
    
    public let participantId: String;
    open var nickname: String?;
    open private(set) var state: ChannelState;
    
    open private(set) var permissions: Set<ChannelPermission>?;
    public let participants: MixParticipantsProtocol = MixParticipantsBase();
    
    public init(context: Context, channelJid: BareJID, participantId: String, nickname: String?, state: ChannelState) {
        self.participantId = participantId;
        self.nickname = nickname;
        self.state = state;
        super.init(context: context, jid: channelJid);
    }
    
    public func update(permissions: Set<ChannelPermission>) {
        self.permissions = permissions;
    }

    public func update(state: ChannelState) -> Bool {
        guard self.state != state else {
            return false;
        }
        self.state = state;
        return true;
    }
}
