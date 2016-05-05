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

public protocol ChatStore {
    
    var count:Int { get }
    var items:[ChatProtocol] { get }
    
    func get<T:ChatProtocol>(jid:BareJID, filter: (T)->Bool) -> T?;
    func getAll<T:ChatProtocol>() -> [T];
    func isFor(jid:BareJID) -> Bool;
    func open<T:ChatProtocol>(chat:ChatProtocol) -> T?;
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

public protocol ChatProtocol: class {
    
    var jid:JID { get set };
    
    var allowFullJid:Bool { get }
}