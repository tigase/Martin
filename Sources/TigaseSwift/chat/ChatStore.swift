//
// ChatStore.swift
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
 Protocol which needs to be implemented by classes responsible for storing Chat instances.
 */
public protocol ChatStore {
    /// Number of open chat protocols
    var count:Int { get }
    /// Array of open chat protocols
    var chats:[Chat] { get }
    
    var dispatcher: QueueDispatcher { get }
    
    /**
     Find instance of T matching jid and filter
     - parameter with: jid to match
     - parameter filter: filter to match
     - returns: instance of T if any matches
     */
    func chat(with jid: BareJID, filter: @escaping (Chat)->Bool) -> Chat?;
    
    /**
     Check if there is any chat open with jid
     - parameter jid: jid to check
     - returns: true if ChatProtocol is open
     */
    func isFor(jid: BareJID) -> Bool;
    /**
     Register opened chat protocol instance
     - parameter chat: chat protocol instance to register
     - returns: registered chat protocol instance (may be new instance)
     */
    func createChat(jid: JID, thread: String?) -> Result<Chat,ErrorCondition>;
    /**
     Unregister closed chat protocol instance
     - parameter chat: chat protocol instance to unregister
     - returns: true if chat protocol instance was unregistered
     */
    func close(chat: Chat) -> Bool;
}

open class DefaultChatStore: ChatStore {
    
    fileprivate var chatsByBareJid = [BareJID:[Chat]]();
    
    public let dispatcher: QueueDispatcher;
    
    open var count:Int {
        get {
            return dispatcher.sync {
                return self.chatsByBareJid.count;
            }
        }
    }
    
    open var chats:[Chat] {
        get {
            return dispatcher.sync {
                return self.chatsByBareJid.values.flatMap({ $0 });
            }
        }
    }

    public init(dispatcher: QueueDispatcher? = nil) {
        self.dispatcher = dispatcher ?? QueueDispatcher(label: "chat_store_queue", attributes: DispatchQueue.Attributes.concurrent);
    }
    
    open func chat(with jid:BareJID, filter: @escaping (Chat)->Bool) -> Chat? {
        return dispatcher.sync {
            if let chats = self.chatsByBareJid[jid] {
                if let idx = chats.firstIndex(where: filter) {
                    return chats[idx];
                }
            }
            return nil;
        }
    }
    
    open func isFor(jid:BareJID) -> Bool {
        var result = false;
        dispatcher.sync {
            let chats = self.chatsByBareJid[jid];
            result = chats != nil && !chats!.isEmpty;
        }
        return result;
    }

    open func createChat(jid: JID, thread: String?) -> Result<Chat, ErrorCondition> {
        return dispatcher.sync(flags: .barrier, execute: {
            var chats = self.chatsByBareJid[jid.bareJid] ?? [Chat]();
            if let fchat = chats.first, fchat.allowFullJid == false {
                return .success(fchat);
            }
            let chat = Chat(jid: jid, thread: thread);
            chats.append(chat);
            self.chatsByBareJid[jid.bareJid] = chats;
            return .success(chat);
        }) 
    }
    
    open func close(chat:Chat) -> Bool {
        let bareJid = chat.jid.bareJid;
        var result = false;
        dispatcher.sync(flags: .barrier, execute: {
            if var chats = self.chatsByBareJid[bareJid] {
                if let idx = chats.firstIndex(where: { (c) -> Bool in
                    c === chat;
                }) {
                    chats.remove(at: idx);
                    if chats.isEmpty {
                        self.chatsByBareJid.removeValue(forKey: bareJid)
                    } else {
                        self.chatsByBareJid[bareJid] = chats;
                    }
                    result = true;
                }
            }
        }) 
        return result;
    }
}

/**
 Protocol to which all chat classes should conform:
 - `Chat` for 1-1 messages
 - `Room` for MUC messages
 - any custom extensions of above classes
 */
public protocol ChatProtocol: class {
    
    /// jid of participant (particpant or MUC jid)
    var jid:JID { get set };
    
    /// Is it allowed to open more than one chat protocol per bare JID?
    var allowFullJid:Bool { get }
}
