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

public protocol ChatManager {
 
    func close(chat:Chat) ->Bool;
    func createChat(jid:JID, thread:String?) -> Chat?;
    func getChat(jid:JID, thread:String?) -> Chat?;
    func getChats() -> [Chat];
    func isChatOpenFor(jid:BareJID) -> Bool;
}

public class Chat: ChatProtocol {
    
    // common variables
    public var jid:JID;
    public let allowFullJid = true;

    // class specific variables
    public var thread:String?;
    
    public init(jid:JID, thread:String?) {
        self.jid = jid;
        self.thread = thread;
    }
    
    public func createMessage(body:String, type:StanzaType = StanzaType.chat, subject:String? = nil, additionalElements:[Element]? = nil) -> Message {
        var msg = Message();
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
