//
// ConversationBase.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

open class ConversationBase: ConversationProtocol {
    
    open weak var context: Context?;
    public let account: BareJID;
    public let jid: BareJID;
    
    open var defaultMessageType: StanzaType {
        return .normal;
    }
    
    public init(context: Context, jid: BareJID) {
        self.context = context;
        self.jid = jid;
        self.account = context.userBareJid;
    }

    public func createMessage(id: String, type: StanzaType) -> Message {
        let msg = Message();
        msg.to = JID(jid);
        msg.id = id;
        msg.originId = id;
        msg.type = type;
        return msg;
    }
    
    open func createMessage(text: String, id: String, type: StanzaType) -> Message {
        let msg = createMessage(id: id, type: type);
        msg.body = text;
        msg.messageDelivery = .request;
        return msg;
    }
    
    public func createMessage(text: String, id: String?) -> Message {
        if let id = id {
            return createMessage(text: text, id: id, type: defaultMessageType);
        } else {
            return createMessage(text: text);
        }
    }
    
    open func send(message: Message, completionHandler: ((Result<Void, XMPPError>) -> Void)?) {
        guard let context = self.context else {
            completionHandler?(.failure(.remote_server_timeout));
            return;
        }
        if message.to == nil {
            message.to = JID(jid);
        }
        context.writer.write(stanza: message, completionHandler: completionHandler);
    }
    
}
