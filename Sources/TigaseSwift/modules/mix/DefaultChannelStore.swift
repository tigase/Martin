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
        
    public typealias Channel = ChannelBase
    
    public let dispatcher = QueueDispatcher(label: "DefaultChannelStore");
    
    private var items: [BareJID: Channel] = [:];

    open func channels(for context: Context) -> [Channel] {
        return dispatcher.sync {
            return Array(items.values);
        }
    }
    
    open func channel(for context: Context, with channelJid: BareJID) -> Channel? {
        return dispatcher.sync {
            return self.items[channelJid];
        }
    }
    
    open func createChannel(for context: Context, with jid: BareJID, participantId: String, nick: String?, state: ChannelState) -> ConversationCreateResult<Channel> {
        return dispatcher.sync {
            guard self.items[jid] == nil else {
                return .none;
            }
            let channel = Channel(context: context, channelJid: jid, participantId: participantId, nickname: nick, state: state);
            self.items[jid] = channel;
            return .created(channel);
        }
    }
    
    open func close(channel: Channel) -> Bool {
        return dispatcher.sync {
            return self.items.removeValue(forKey: channel.jid) != nil;
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
    
    public func update(channel: Channel, info: ChannelInfo) -> Bool {
        // we are not storing channel info in this case.. or maybe we should???
        return false;
    }
    
    public func update(channel: Channel, state: ChannelState) -> Bool {
        return dispatcher.sync {
            return channel.update(state: state);
        }
    }
    
    public func initialize(context: Context) {
        
    }
    
    public func deinitialize(context: Context) {
        
    }
}
