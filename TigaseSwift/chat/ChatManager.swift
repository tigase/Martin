//
// ChatManager.swift
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
 Protocol which needs to be implemented by classes responsible for handling Chats
 */
public protocol ChatManager {
 
    /// Number of open chats
    var count:Int { get }
    
    /**
     Close chat
     - parameter chat: chat to close
     - returns: true - if chat was closed
     */
    func close(chat:Chat) ->Bool;
    
    /**
     Create chat
     - parameter with: jid to exchange messages
     - parameter thread: id of thread
     - returns: instance of Chat if opened
     */
    func createChat(with jid:JID, thread:String?) -> Chat?;
    /**
     Get instance of already opened chat
     - parameter with: jid to exchange messages
     - parameter thread: id of thread
     - returns: instance of Chat if any opened and matches
     */
    func getChat(with jid:JID, thread:String?) -> Chat?;
    /**
     Get array of opened chats
     - returns: array of all currently open chats
     */
    func getChats() -> [Chat];
    /**
     Check if there is any chat open with jid
     - parameter with: jid to check
     */
    func isChatOpen(with jid:BareJID) -> Bool;
}

/**
 Implementation of Chat
 */
open class Chat: ChatProtocol {
    
    fileprivate static let queue = DispatchQueue(label: "chat_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    // common variables
    fileprivate var _jid: JID;
    /// JID with which messages are exchanged
    open var jid: JID {
        get {
            var r: JID!;
            Chat.queue.sync {
                r = self._jid;
            }
            return r;
        }
        set {
            Chat.queue.async(flags: .barrier, execute: {
                self._jid = newValue;
            }) 
        }
    }
    /// Is it possible to open many chats with same bare JID?
    open let allowFullJid = true;

    // class specific variables
    /// Thread ID of message exchange
    fileprivate var _thread: String?;
    open var thread:String? {
        get {
            var r: String?;
            Chat.queue.sync {
                r = self._thread;
            }
            return r;
        }
        set {
            Chat.queue.async(flags: .barrier, execute: {
                self._thread = newValue;
            }) 
        }
    }
    
    public init(jid:JID, thread:String?) {
        self._jid = jid;
        self._thread = thread;
    }
    
    /**
     Create message to send to recipient
     - parameter body: text to send
     - parameter type: type of message
     - parameter subject: subject of message
     - parameter additionalElements: additional elements to add to message
     */
    open func createMessage(_ body:String, type:StanzaType = StanzaType.chat, subject:String? = nil, additionalElements:[Element]? = nil) -> Message {
        let msg = Message();
        msg.to = jid;
        msg.type = type;
        msg.thread = thread;
        msg.body = body;
        msg.subject = subject;
        if additionalElements != nil {
            msg.addChildren(additionalElements!);
        }
        
        return msg;
    }
}
