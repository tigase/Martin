//
// ChannelManagerBase.swift
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

open class BaseChannelManagerBase<Channel: ChannelProtocol> {
    
    init() {
    }
    
    func cast(_ channel: ChannelProtocol) -> Channel {
        return channel as! Channel;
    }
    
}

open class ChannelManagerBase<Store: ChannelStore>: BaseChannelManagerBase<Store.Channel>, ChannelManager {
 
    public let store: Store;
    
    public init(store: Store) {
        self.store = store;
    }
 
    public func channels(for context: Context) -> [ChannelProtocol] {
        return store.channels(for: context);
    }
    
    public func createChannel(for context: Context, with jid: BareJID, participantId: String, nick: String?, state: ChannelState) -> ConversationCreateResult<ChannelProtocol> {
        switch store.createChannel(for: context, with: jid, participantId: participantId, nick: nick, state: state) {
        case .created(let channel):
            return .created(channel);
        case .found(let channel):
            return .found(channel);
        case .none:
            return .none;
        }
    }
    
    public func channel(for context: Context, with channelJid: BareJID) -> ChannelProtocol? {
        return store.channel(for: context, with: channelJid);
    }
    
    public func close(channel: ChannelProtocol) -> Bool {
        return store.close(channel: cast(channel));
    }
    
    public func initialize(context: Context) {
        store.initialize(context: context);
    }
    
    public func deinitialize(context: Context) {
        store.deinitialize(context: context);
    }
}
