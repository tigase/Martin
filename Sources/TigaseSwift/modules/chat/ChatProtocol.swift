//
// ChatProtocol.swift
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

public protocol ChatProtocol: ConversationProtocol {
    
}

extension ChatProtocol {
    
    public func sendMessage(_ body: String, subject: String?, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        guard let context = context else {
            completionHandler(.failure(.recipient_unavailable(nil)));
            return;
        }
        
        let message = createMessage(body, subject: subject);
        context.writer.write(message, writeCompleted: completionHandler);
    }
    
    public func createMessage(_ body:String, type:StanzaType = StanzaType.chat, subject:String? = nil, additionalElements:[Element]? = nil) -> Message {
        let msg = Message();
        msg.to = jid;
        msg.type = type;
        msg.body = body;
        msg.subject = subject;
        
        if additionalElements != nil {
            msg.addChildren(additionalElements!);
        }
    
        return msg;
    }
    
}
