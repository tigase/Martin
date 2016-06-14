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
    func get<T:ChatProtocol>(jid:BareJID, filter: (T)->Bool) -> T?;
    /**
     Find all instances conforming to implementation of T
     */
    func getAll<T:ChatProtocol>() -> [T];
    
    /**
     Check if there is any chat open with jid
     - parameter jid: jid to check
     - returns: true if ChatProtocol is open
     */
    func isFor(jid:BareJID) -> Bool;
    /**
     Register opened chat protocol instance
     - parameter chat: chat protocol instance to register
     - returns: registered chat protocol instance (may be new instance)
     */
    func open<T:ChatProtocol>(chat:ChatProtocol) -> T?;
    /**
     Unregister closed chat protocol instance
     - parameter chat: chat protocol instance to unregister
     - returns: true if chat protocol instance was unregistered
     */
    func close(chat:ChatProtocol) -> Bool;
}

public class DefaultChatStore: ChatStore {
    
    private var chatsByBareJid = [BareJID:[ChatProtocol]]();
    
    public var count:Int {
        get {
            return chatsByBareJid.count;
        }
    }
    
    public var items:[ChatProtocol] {
        get {
            var result = [ChatProtocol]();
            chatsByBareJid.values.forEach { (chats) in
                result.appendContentsOf(chats);
            }
            return result;
        }
    }

    public func get<T>(jid:BareJID, filter: (T)->Bool) -> T? {
        if let chats = chatsByBareJid[jid] {
            if let idx = chats.indexOf({
                if let item:T = $0 as? T {
                    return filter(item);
                }
                return false;
            }) {
                return chats[idx] as? T;
            }
        }
        return nil;
    }
    
    public func getAll<T>() -> [T] {
        var result = [T]();
        chatsByBareJid.values.forEach { (chats) in
            chats.forEach { (chat) in
                if let ch = chat as? T {
                    result.append(ch);
                }
            };
        }
        return result;
    }
    
    
    public func isFor(jid:BareJID) -> Bool {
        let chats = chatsByBareJid[jid];
        return chats != nil && !chats!.isEmpty;
    }

    public func open<T>(chat:ChatProtocol) -> T? {
        let jid = chat.jid;
        var chats = chatsByBareJid[jid.bareJid] ?? [ChatProtocol]();
        let fchat = chats.first;
        if fchat != nil && fchat?.allowFullJid == false {
            return fchat as? T;
        }
        chats.append(chat);
        chatsByBareJid[jid.bareJid] = chats;
        return chat as? T;
    }
    
    public func close(chat:ChatProtocol) -> Bool {
        let bareJid = chat.jid.bareJid;
        if var chats = chatsByBareJid[bareJid] {
            if let idx = chats.indexOf({ (c) -> Bool in
                c === chat;
            }) {
                chats.removeAtIndex(idx);
                if chats.isEmpty {
                    chatsByBareJid.removeValueForKey(bareJid)
                } else {
                    chatsByBareJid[bareJid] = chats;
                }
                return true;
            }
        }
        return false;
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