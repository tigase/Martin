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
    var items:[ChatProtocol] { get }
    
    /**
     Find instance of T matching jid and filter
     - parameter jid: jid to match
     - parameter filter: filter to match
     - returns: instance of T if any matches
     */
    func get<T:ChatProtocol>(_ jid:BareJID, filter: @escaping (T)->Bool) -> T?;
    /**
     Find all instances conforming to implementation of T
     */
    func getAll<T:ChatProtocol>() -> [T];
    
    /**
     Check if there is any chat open with jid
     - parameter jid: jid to check
     - returns: true if ChatProtocol is open
     */
    func isFor(_ jid:BareJID) -> Bool;
    /**
     Register opened chat protocol instance
     - parameter chat: chat protocol instance to register
     - returns: registered chat protocol instance (may be new instance)
     */
    func open<T:ChatProtocol>(_ chat:ChatProtocol) -> T?;
    /**
     Unregister closed chat protocol instance
     - parameter chat: chat protocol instance to unregister
     - returns: true if chat protocol instance was unregistered
     */
    func close(_ chat:ChatProtocol) -> Bool;
}

open class DefaultChatStore: ChatStore {
    
    fileprivate var chatsByBareJid = [BareJID:[ChatProtocol]]();
    
    fileprivate let queue = DispatchQueue(label: "chat_store_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    open var count:Int {
        get {
            var result = 0;
            queue.sync {
                result = self.chatsByBareJid.count;
            }
            return result;
        }
    }
    
    open var items:[ChatProtocol] {
        get {
            var result = [ChatProtocol]();
            queue.sync {
                self.chatsByBareJid.values.forEach { (chats) in
                    result.append(contentsOf: chats);
                }
            }
            return result;
        }
    }

    open func get<T>(_ jid:BareJID, filter: @escaping (T)->Bool) -> T? {
        var result: T?;
        queue.sync {
            if let chats = self.chatsByBareJid[jid] {
                if let idx = chats.index(where: {
                    if let item:T = $0 as? T {
                        return filter(item);
                    }
                    return false;
                }) {
                    result = chats[idx] as? T;
                }
            }
        }
        return result;
    }
    
    open func getAll<T>() -> [T] {
        var result = [T]();
        queue.sync {
            self.chatsByBareJid.values.forEach { (chats) in
                chats.forEach { (chat) in
                    if let ch = chat as? T {
                        result.append(ch);
                    }
                };
            }
        }
        return result;
    }
    
    
    open func isFor(_ jid:BareJID) -> Bool {
        var result = false;
        queue.sync {
            let chats = self.chatsByBareJid[jid];
            result = chats != nil && !chats!.isEmpty;
        }
        return result;
    }

    open func open<T>(_ chat:ChatProtocol) -> T? {
        let jid = chat.jid;
        var result: T?;
        queue.sync(flags: .barrier, execute: {
            var chats = self.chatsByBareJid[jid.bareJid] ?? [ChatProtocol]();
            let fchat = chats.first;
            if fchat != nil && fchat?.allowFullJid == false {
                result = fchat as? T;
                return;
            }
            result = chat as? T;
            
            chats.append(chat);
            self.chatsByBareJid[jid.bareJid] = chats;
        }) 
        return result;
    }
    
    open func close(_ chat:ChatProtocol) -> Bool {
        let bareJid = chat.jid.bareJid;
        var result = false;
        queue.sync(flags: .barrier, execute: {
            if var chats = self.chatsByBareJid[bareJid] {
                if let idx = chats.index(where: { (c) -> Bool in
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
