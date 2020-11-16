//
// ChatManagerBase.swift
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

open class BaseChatManagerBase<Chat: ChatProtocol> {
    
    init() {
    }
    
    func cast(_ channel: ChatProtocol) -> Chat {
        return channel as! Chat;
    }
    
}

open class ChatManagerBase<Store: ChatStore>: BaseChatManagerBase<Store.Chat>, ChatManager {
    
    public let store: Store;

    public init(store: Store) {
        self.store = store;
    }
    
    public func chats(for context: Context) -> [ChatProtocol] {
        return store.chats(for: context);
    }
    
    public func chat(for context: Context, with jid: JID) -> ChatProtocol? {
        return store.chat(for: context, with: jid)
    }
    
    public func createChat(for context: Context, with jid: JID) -> ChatProtocol? {
        switch store.createChat(for: context, with: jid) {
        case .created(let chat):
            context.eventBus.fire(MessageModule.ChatCreatedEvent(context: context, chat: chat));
            return chat;
        case .found(let chat):
            return chat;
        case .none:
            return nil;
        }
    }
    
    open func close(chat: ChatProtocol) -> Bool {
        let result = store.close(chat: chat as! Store.Chat);
        if result, let context = chat.context {
            context.eventBus.fire(MessageModule.ChatClosedEvent(context: context, chat: chat));
        }
        return result;
    }
    
    open func initialize(context: Context) {
        store.initialize(context: context);
    }
    
    open func deinitialize(context: Context) {
        store.deinitialize(context: context);
    }
    
}
