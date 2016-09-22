//
// DefaultChatManager.swift
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

/**
 Default implementation of `ChatManager` protocol.
 
 It is only responsible for opening, closing and retrieving chats from chat store.
 */
open class DefaultChatManager: ChatManager {
    
    open let chatStore:ChatStore;
    open let context:Context;
    
    open var count:Int {
        get {
            return chatStore.count;
        }
    }
    
    public init(context: Context, chatStore:ChatStore = DefaultChatStore()) {
        self.context = context;
        self.chatStore = chatStore;
    }
    
    open func close(chat: Chat) -> Bool {
        let result = chatStore.close(chat: chat);
        if result {
            context.eventBus.fire(MessageModule.ChatClosedEvent(sessionObject: context.sessionObject, chat: chat));
        }
        return result;
    }
    
    open func createChat(with jid: JID, thread: String? = nil) -> Chat? {
        let chat:Chat? = chatStore.open(chat: Chat(jid: jid, thread: thread));
        if chat != nil {
            context.eventBus.fire(MessageModule.ChatCreatedEvent(sessionObject: context.sessionObject, chat:chat!));
        }
        return chat;
    }
    
    open func getChat(with jid:JID, thread:String? = nil) -> Chat? {
        var chat:Chat? = nil;
        
        if thread != nil {
            chat = chatStore.getChat(with: jid.bareJid, filter:{ (c) -> Bool in
                return c.thread == thread;
            });
        }
        
        if chat == nil && jid.resource != nil {
            chat = chatStore.getChat(with: jid.bareJid, filter: { (c) -> Bool in
                return c.jid == jid;
            });
        }
        
        if chat == nil {
            chat = chatStore.getChat(with: jid.bareJid, filter: { (c) -> Bool in
                return c.jid.bareJid == jid.bareJid;
            });
        }
        
        return chat;
    }
    
    open func getChats() -> [Chat] {
        return chatStore.getAllChats();
    }
    
    open func isChatOpen(with jid: BareJID) -> Bool {
        return chatStore.isFor(jid: jid);
    }
}
