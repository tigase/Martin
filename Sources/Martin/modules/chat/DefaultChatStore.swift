//
// DefaultChatStore.swift
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

open class DefaultChatStore: ChatStore {

    public typealias Chat = ChatBase;
    
    private var chats = [BareJID: Chat]();
    
    public let queue = DispatchQueue(label: "DefaultChatStoreQueue");
    
    public init() {
        
    }
    
    public func chats(for: Context) -> [Chat] {
        return queue.sync {
            return chats.values.compactMap({ $0 });
        }
    }
    
    public func chat(for: Context, with jid: BareJID) -> Chat? {
        return queue.sync {
            return chats[jid];
        }
    }
    
    public func createChat(for context: Context, with jid: BareJID) -> ConversationCreateResult<Chat> {
        return queue.sync {
            guard let chat = chat(for: context, with: jid) else {
                let chat = Chat(context: context, jid: jid);
                chats[jid] = chat;
                return .created(chat);
            }
            return .found(chat);
        }
    }
    
    public func close(chat: Chat) -> Bool {
        return queue.sync {
            return chats.removeValue(forKey: chat.jid) != nil;
        }
    }
    
    public func initialize(context: Context) {
        // nothing to do?
    }
    
    public func deinitialize(context: Context) {
        // nothing to do?
    }
}
