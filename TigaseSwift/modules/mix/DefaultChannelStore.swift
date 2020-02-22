//
// DefaultChannelStore.swift
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

open class DefaultChannelStore: ChannelStore {
        
    public let dispatcher = QueueDispatcher(label: "DefaultChannelStore");
    
    private var channels: [BareJID: Channel] = [:];

    open func channel(for channelJid: BareJID) -> Channel? {
        return dispatcher.sync {
            return self.channels[channelJid];
        }
    }
    
    open func createChannel(jid: BareJID, participantId: String, nick: String?) -> Result<Channel,ErrorCondition> {
        return dispatcher.sync {
            guard self.channels[jid] == nil else {
                return .failure(.conflict);
            }
            let channel = Channel(channelJid: jid, participantId: participantId, nickname: nick);
            self.channels[jid] = channel;
            return .success(channel);
        }
    }
    
    open func close(channel: Channel) -> Bool {
        return dispatcher.sync {
            return self.channels.removeValue(forKey: channel.channelJid) != nil;
        }
    }

    public func update(channel: Channel, nick: String?) -> Bool {
        return dispatcher.sync {
            guard channel.nickname != nick else {
                return false;
            }
            channel.nickname = nick;
            return true;
        }
    }
}
