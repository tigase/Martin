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

public class DefaultChatManager: ChatManager {
    
    public let chatStore:ChatStore;
    public let context:Context;
    
    public var count:Int {
        get {
            return chatStore.count;
        }
    }
    
    public init(context: Context, chatStore:ChatStore = DefaultChatStore()) {
        self.context = context;
        self.chatStore = chatStore;
    }
    
    public func close(chat: Chat) -> Bool {
        let result = chatStore.close(chat);
        if result {
            context.eventBus.fire(MessageModule.ChatClosedEvent(sessionObject: context.sessionObject, chat: chat));
        }
        return result;
    }
    
    public func createChat(jid: JID, thread: String? = nil) -> Chat? {
        let chat:Chat? = chatStore.open(Chat(jid: jid, thread: thread));
        if chat != nil {
            context.eventBus.fire(MessageModule.ChatCreatedEvent(sessionObject: context.sessionObject, chat:chat!));
        }
        return chat;
    }
    
    public func getChat(jid:JID, thread:String? = nil) -> Chat? {
        var chat:Chat? = nil;
        
        if thread != nil {
            chat = chatStore.get(jid.bareJid, filter:{ (c) -> Bool in
                return c.thread == thread;
            });
        }
        
        if chat == nil && jid.resource != nil {
            chat = chatStore.get(jid.bareJid, filter: { (c) -> Bool in
                return c.jid == jid;
            });
        }
        
        if chat == nil {
            chat = chatStore.get(jid.bareJid, filter: { (c) -> Bool in
                return c.jid.bareJid == jid.bareJid;
            });
        }
        
        return chat;
    }
    
    public func getChats() -> [Chat] {
        return chatStore.getAll();
    }
    
    public func isChatOpenFor(jid: BareJID) -> Bool {
        return chatStore.isFor(jid);
    }
}