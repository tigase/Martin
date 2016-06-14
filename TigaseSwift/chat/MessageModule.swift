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

/**
 Module provides features responsible for handling messages
 */
public class MessageModule: XmppModule, ContextAware, Initializable {
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "message";
    
    public let id = ID;
    
    public let criteria = Criteria.name("message", types:[StanzaType.chat, StanzaType.normal, StanzaType.headline, StanzaType.error]);
    
    public let features = [String]();
    
    /// Instance of `ChatManager`
    public var chatManager:ChatManager!;
    
    public var context:Context!
    
    public init() {
        
    }
    
    /**
     Create chat for message exchange
     - parameter jid: recipient of messages
     - parameter thread: thread id of chat
     - returns: instance of `Chat`
     */
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
        try processMessage(message, interlocutorJid: message.from);
    }
    
    func processMessage(message: Message, interlocutorJid: JID?, fireEvents: Bool = true) -> Chat? {
        var chat = chatManager.getChat(interlocutorJid!, thread: message.thread);
        
        if chat == nil && message.body == nil {
            fire(MessageReceivedEvent(sessionObject: context.sessionObject, chat: nil, message: message));
            return nil;
        }
        
        if chat == nil {
            chat = chatManager.createChat(interlocutorJid!, thread: message.thread);
        } else {
            if chat!.jid != interlocutorJid {
                chat!.jid = interlocutorJid!;
            }
            if chat!.thread != message.thread {
                chat!.thread = message.thread;
            }
        }
        
        if chat != nil &&  fireEvents {
            fire(MessageReceivedEvent(sessionObject: context.sessionObject, chat: chat, message: message));
        }
        
        return chat;
    }
    
    /**
     Send message as part of message exchange
     - parameter chat: instance of Chat
     - parameter body: text of message to send
     - parameter type: type of message
     - parameter subject: subject of message
     - parameter additionalElements: array of additional elements to add to message
     */
    public func sendMessage(chat:Chat, body:String, type:StanzaType = StanzaType.chat, subject:String? = nil, additionalElements:[Element]? = nil) -> Message {
        let msg = chat.createMessage(body, type: type, subject: subject, additionalElements: additionalElements);
        context.writer?.write(msg);
        return msg;
    }
    
    func fire(event:Event) {
        context.eventBus.fire(event);
    }
    
    /// Event fired when Chat is created/opened
    public class ChatCreatedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChatCreatedEvent();
        
        public let type = "ChatCreatedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Instance of opened chat
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

    /// Event fired when Chat is closed
    public class ChatClosedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChatClosedEvent();
        
        public let type = "ChatClosedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Instance of closed chat
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
    
    /// Event fired when message is received
    public class MessageReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = MessageReceivedEvent();
        
        public let type = "MessageReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Instance of chat to which this message belongs
        public let chat:Chat?;
        /// Received message
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