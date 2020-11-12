//
// DefaultChannelManager.swift
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

open class DefaultChannelManager: ChannelManager {
    
    public let store: ChannelStore;
    public weak var context: Context!;
    
    public init(context: Context, store: ChannelStore) {
        self.context = context;
        self.store = store;
    }
    
    open func createChannel(jid: BareJID, participantId: String, nick: String?, state: Channel.State) -> Result<Channel, ErrorCondition> {
        return store.dispatcher.sync(execute: {
            if let channel = store.channel(for: jid) {
                if channel.participantId == participantId {
                    _ = store.update(channel: channel, state: state);
                    return .success(channel);
                } else {
                    if store.close(channel: channel) {
                        self.context.eventBus.fire(ChannelClosedEvent(context: self.context, channel: channel));
                    }
                }
            }
            let result = store.createChannel(jid: jid, participantId: participantId, nick: nick, state: state);
            switch result {
            case .success(let channel):
                self.context.eventBus.fire(ChannelCreatedEvent(context: self.context, channel: channel));
            default:
                break;
            }
            return result;
        })
    }
    
    open func channels() -> [Channel] {
        return store.channels();
    }

    open func channel(for channelJid: BareJID) -> Channel? {
        return store.channel(for: channelJid);
    }
    
    open func close(channel: Channel) -> Bool {
        if store.close(channel: channel) {
            self.context.eventBus.fire(ChannelClosedEvent(context: self.context, channel: channel));
            return true;
        }
        return false;
    }
    
    open func update(channel: Channel, nick: String?) -> Bool {
        if store.update(channel: channel, nick: nick) {
            self.context.eventBus.fire(ChannelUpdatedEvent(context: self.context, channel: channel));
            return true;
        }
        return false;
    }

    open func update(channel jid: BareJID, info: ChannelInfo) -> Bool {
        guard let channel = channel(for: jid) else {
            return false;
        }
        if store.update(channel: channel, info: info) {
            self.context.eventBus.fire(ChannelUpdatedEvent(context: self.context, channel: channel));
            return true;
        }
        return false;
    }

    open func update(channel jid: BareJID, state: Channel.State) -> Bool {
        guard let channel = channel(for: jid) else {
            return false;
        }
        if store.update(channel: channel, state: state) {
            self.context.eventBus.fire(ChannelUpdatedEvent(context: self.context, channel: channel));
            return true;
        }
        return false;
    }

    open class ChannelCreatedEvent: AbstractEvent {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChannelCreatedEvent();

        public let channel: Channel!;
        
        private init() {
            channel = nil;
            super.init(type: "MixChannelManagerChannelCreatedEvent")
        }
        
        public init(context: Context, channel: Channel) {
            self.channel = channel;
            super.init(type: "MixChannelManagerChannelCreatedEvent", context: context)
        }
    }

    open class ChannelClosedEvent: AbstractEvent {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChannelClosedEvent();

        public let channel: Channel!;
        
        private init() {
            channel = nil;
            super.init(type: "MixChannelManagerChannelClosedEvent")
        }
        
        public init(context: Context, channel: Channel) {
            self.channel = channel;
            super.init(type: "MixChannelManagerChannelClosedEvent", context: context)
        }
    }

    open class ChannelUpdatedEvent: AbstractEvent {
        
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChannelUpdatedEvent();

        public let channel: Channel!;
        
        private init() {
            channel = nil;
            super.init(type: "MixChannelManagerChannelUpdatedEvent")
        }
        
        public init(context: Context, channel: Channel) {
            self.channel = channel;
            super.init(type: "MixChannelManagerChannelUpdatedEvent", context: context);
        }
    }

}
