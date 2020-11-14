//
// ChannelStore.swift
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

public protocol ChannelStore: ContextLifecycleAware {

    associatedtype Channel: ChannelProtocol
    
    var dispatcher: QueueDispatcher { get }
//    var channelEvents: AnyPublisher<ConverstaionStoreAction<Channel>,Never> { get }

    func channels(for context: Context) -> [Channel];
    
    func channel(for context: Context, with jid: BareJID) -> Channel?;
    
    func createChannel(for context: Context, with jid: BareJID, participantId: String, nick: String?, state: ChannelState) -> ConversationCreateResult<Channel>;
    
    func close(channel: Channel) -> Bool;
    
    func update(channel: Channel, nick: String?) -> Bool;
    
    func update(channel: Channel, info: ChannelInfo) -> Bool;
    
    func update(channel: Channel, state: ChannelState) -> Bool;
    
}

//public enum ConverstaionStoreAction<Conversation: ConverstaionProtocol> {
//    case added([Conversation])
//    case updated([Conversation])
//    case removed([Conversation])
//}
