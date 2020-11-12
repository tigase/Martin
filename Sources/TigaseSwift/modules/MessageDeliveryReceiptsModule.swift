//
// MessageDeliveryReceiptsModule.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
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
    public static var messageDeliveryReceipts: XmppModuleIdentifier<MessageDeliveryReceiptsModule> {
        return MessageDeliveryReceiptsModule.IDENTIFIER;
    }
}

open class MessageDeliveryReceiptsModule: XmppModuleBase, XmppModule {
    
    /// Namespace used by Message Carbons
    public static let XMLNS = "urn:xmpp:receipts";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<MessageDeliveryReceiptsModule>();
    
    public let criteria = Criteria.name("message").add(Criteria.xmlns(XMLNS));
    
    public let features = [XMLNS];
    
    open var sendReceived: Bool = true;
    
    public override init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        guard let message = stanza as? Message, stanza.type != StanzaType.error else {
            return;
        }
        
        guard let delivery = message.messageDelivery else {
            return;
        }
        
        switch delivery {
        case .request:
            guard let id = message.id, message.from != nil, message.type != .groupchat else {
                return;
            }
            // need to send response/ack
            let response = Message();
            response.type = message.type;
            response.to = message.from;
            response.messageDelivery = MessageDeliveryReceiptEnum.received(id: id);
            response.hints = [.store];
            write(response);
            break;
        case .received(let id):
            // need to notify client - fire event
            if let context = context {
                fire(ReceiptEvent(context: context, message: message, messageId: id));
            }
            break;
        }
    }
    
    /// Event fired when message delivery confirmation is received
    open class ReceiptEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ReceiptEvent();
        
        /// Received message
        public let message:Message!;
        /// ID of confirmed message
        public let messageId: String!;
        
        
        fileprivate init() {
            self.messageId = nil;
            self.message = nil;
            super.init(type: "MessageDeliveryReceiptReceivedEvent")
        }
        
        public init(context: Context, message: Message, messageId: String) {
            self.message = message;
            self.messageId = messageId;
            super.init(type: "MessageDeliveryReceiptReceivedEvent", context: context)
        }
    }
}

extension Message {
    
    open var messageDelivery: MessageDeliveryReceiptEnum? {
        get {
            if let el = element.findChild(xmlns: MessageDeliveryReceiptsModule.XMLNS) {
                switch el.name {
                case "request":
                    return MessageDeliveryReceiptEnum.request;
                case "received":
                    if let id = el.getAttribute("id") {
                        return MessageDeliveryReceiptEnum.received(id: id);
                    }
                default:
                    break;
                }
            }
            return nil;
        }
        set {
            element.getChildren(xmlns: MessageDeliveryReceiptsModule.XMLNS).forEach { (el) in
                element.removeChild(el);
            }
            if newValue != nil {
                if self.id == nil {
                    self.id = UUID().description;
                }
                switch newValue! {
                case .request:
                    element.addChild(Element(name: "request", xmlns: MessageDeliveryReceiptsModule.XMLNS));
                case .received(let id):
                    let el = Element(name: "received", xmlns: MessageDeliveryReceiptsModule.XMLNS);
                    el.setAttribute("id", value: id);
                    element.addChild(el);
                }
            }
        }
    }
    
}

public enum MessageDeliveryReceiptEnum {
    case request
    case received(id: String)
    
    func getMessageId() -> String? {
        switch self {
        case .received(let id):
            return id;
        default:
            return nil;
        }
    }
}
