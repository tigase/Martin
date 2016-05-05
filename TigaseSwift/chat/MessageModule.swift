//
// MessageModule.swift
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

public class MessageModule: XmppModule, ContextAware, Initializable {
    
    public static let ID = "message";
    
    public let id = ID;
    
    public let criteria = Criteria.name("message", types:[StanzaType.chat, StanzaType.normal, StanzaType.headline, StanzaType.error]);
    
    public let features = [String]();
    
    public var chatManager:ChatManager!;
    
    public var context:Context!
    
    public init() {
        
    }
    
    public func createChat(jid:JID, thread: String? = UIDGenerator.nextUid) -> Chat? {
        return chatManager.createChat(jid, thread: thread);
    }
    
    public func initialize() {
        if chatManager == nil {
            chatManager = DefaultChatManager(context: context);
        }
    }
    
    public func process(stanza: Stanza) throws {
        let message = stanza as! Message;
        try processMessage(message);
    }
    
    func processMessage(message: Message) throws {
        var chat = chatManager.getChat(message.from!, thread: message.thread);
        
        if chat == nil && message.body == nil {
            fire(MessageReceivedEvent(sessionObject: context.sessionObject, chat: nil, message: message));
        }
        
        if chat == nil {
            chat = chatManager.createChat(message.from!, thread: message.thread);
        } else {
            if chat!.jid != message.from {
                chat!.jid = message.from!;
            }
            if chat!.thread != message.thread {
                chat!.thread = message.thread;
            }
        }
        
        if chat != nil {
            fire(MessageReceivedEvent(sessionObject: context.sessionObject, chat: chat, message: message));
        }
    }
    
    public func sendMessage(chat:Chat, body:String, type:StanzaType = StanzaType.chat, subject:String? = nil, additionalElements:[Element]? = nil) -> Message {
        let msg = chat.createMessage(body, type: type, subject: subject, additionalElements: additionalElements);
        context.writer?.write(msg);
        return msg;
    }
    
    func fire(event:Event) {
        context.eventBus.fire(event);
    }
    
    public class ChatCreatedEvent: Event {
        public static let TYPE = ChatCreatedEvent();
        
        public let type = "ChatCreatedEvent";
        
        public let sessionObject:SessionObject!;
        public let chat:Chat!;
        
        private init() {
            self.sessionObject = nil;
            self.chat = nil;
        }
        
        public init(sessionObject:SessionObject, chat:Chat) {
            self.sessionObject = sessionObject;
            self.chat = chat;
        }
    }

    public class ChatClosedEvent: Event {
        public static let TYPE = ChatClosedEvent();
        
        public let type = "ChatClosedEvent";
        
        public let sessionObject:SessionObject!;
        public let chat:Chat!;
        
        private init() {
            self.sessionObject = nil;
            self.chat = nil;
        }
        
        public init(sessionObject:SessionObject, chat:Chat) {
            self.sessionObject = sessionObject;
            self.chat = chat;
        }
    }
    
    public class MessageReceivedEvent: Event {
        public static let TYPE = MessageReceivedEvent();
        
        public let type = "MessageReceivedEvent";
        
        public let sessionObject:SessionObject!;
        public let chat:Chat?;
        public let message:Message!;
        
        private init() {
            self.sessionObject = nil;
            self.chat = nil;
            self.message = nil;
        }
        
        public init(sessionObject:SessionObject, chat:Chat?, message:Message) {
            self.sessionObject = sessionObject;
            self.chat = chat;
            self.message = message;
        }
    }
    
}