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

extension XmppModuleIdentifier {
    public static var message: XmppModuleIdentifier<MessageModule> {
        return MessageModule.IDENTIFIER;
    }
}

/**
 Module provides features responsible for handling messages
 */
open class MessageModule: XmppModuleBase, XmppModule {
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "message";
    public static let IDENTIFIER = XmppModuleIdentifier<MessageModule>();
        
    public let criteria = Criteria.name("message", types:[StanzaType.chat, StanzaType.normal, nil, StanzaType.headline, StanzaType.error]);
    
    public let features = [String]();
    
    /// Instance of `chatManager`
    public let chatManager: ChatManager;
    
    open override var context: Context? {
        didSet {
            oldValue?.unregister(lifecycleAware: chatManager);
            context?.register(lifecycleAware: chatManager);
        }
    }
//    public convenience init(client: XMPPClient) {
//        self.init(chatsManager: DefaultchatsManager(context: client.context));
//    }
    
    public init(chatManager: ChatManager) {
        self.chatManager = chatManager;
    }
        
    open func process(stanza: Stanza) {
        let message = stanza as! Message;
        _ = processMessage(message, interlocutorJid: message.from);
    }
    
    open func processMessage(_ message: Message, interlocutorJid: JID?, fireEvents: Bool = true) -> ChatProtocol? {
        guard let context = self.context else {
            return nil;
        }
        guard let jid = interlocutorJid, let chat = chat(forMessage: message, interlocutorJid: jid, context: context) else {
            return nil;
        }
                
        if fireEvents {
            fire(MessageReceivedEvent(context: context, chat: chat, message: message));
        }
        
        return chat;
    }
    
    private func chat(forMessage message: Message, interlocutorJid: JID, context: Context) -> ChatProtocol? {
        // do not process 1-1 chats for MUCs
        guard message.findChild(name: "x", xmlns: "jabber:x:conference") == nil || context.moduleOrNil(.muc) == nil else {
            return nil;
        }
        
        guard let chat = chatManager.chat(for: context, with: interlocutorJid.bareJid) else {
            guard message.body != nil else {
                return nil;
            }
            return chatManager.createChat(for: context, with: interlocutorJid.bareJid);
        }
        
        return chat;
    }
        
    /// Event fired when Chat is created/opened
    open class ChatCreatedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChatCreatedEvent();
        
        /// Instance of opened chat
        public let chat:ChatProtocol!;
        
        fileprivate init() {
            self.chat = nil;
            super.init(type: "ChatCreatedEvent");
        }
        
        public init(context: Context, chat: ChatProtocol) {
            self.chat = chat;
            super.init(type: "ChatCreatedEvent", context: context);
        }
    }

    /// Event fired when Chat is closed
    open class ChatClosedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ChatClosedEvent();
        
        /// Instance of closed chat
        public let chat:ChatProtocol!;
        
        fileprivate init() {
            self.chat = nil;
            super.init(type: "ChatClosedEvent")
        }
        
        public init(context: Context, chat:ChatProtocol) {
            self.chat = chat;
            super.init(type: "ChatClosedEvent", context: context);
        }
    }
    
    /// Event fired when message is received
    open class MessageReceivedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = MessageReceivedEvent();
        
        public let chat:ChatProtocol!;
        /// Received message
        public let message:Message!;
        
        fileprivate init() {
            self.chat = nil;
            self.message = nil;
            super.init(type: "MessageReceivedEvent");
        }
        
        public init(context: Context, chat:ChatProtocol, message:Message) {
            self.chat = chat;
            self.message = message;
            super.init(type: "MessageReceivedEvent", context: context);
        }
    }
    
}
