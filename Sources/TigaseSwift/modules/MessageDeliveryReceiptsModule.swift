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
import Combine

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
    
    open override var context: Context? {
        didSet {
            context?.moduleOrNil(.messageCarbons)?.carbonsPublisher.sink(receiveValue: { [weak self] carbon in
                self?.handleCarbon(carbon: carbon);
            }).store(in: self);
            context?.moduleOrNil(.mam)?.archivedMessagesPublisher.sink(receiveValue: { [weak self] archived in
                self?.handleArchived(archived: archived);
            }).store(in: self);
        }
    }
    
    public let receiptsPublisher = PassthroughSubject<Receipt, Never>();
    
    public override init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        guard let message = stanza as? Message else {
            return;
        }
        
        process(message: message, sendReceived: sendReceived);
    }
    
    private func handleArchived(archived: MessageArchiveManagementModule.ArchivedMessageReceived) {
        process(message: archived.message, sendReceived: false);
    }
    
    private func handleCarbon(carbon: MessageCarbonsModule.CarbonReceived) {
        process(message: carbon.message, sendReceived: false);
    }
    
    private func process(message: Message, sendReceived: Bool) {
        guard message.type != StanzaType.error, let delivery = message.messageDelivery, let jid = message.from else {
            return;
        }
        
        switch delivery {
        case .request:
            guard sendReceived else {
                return;
            }
            
            self.sendReceived(for: message);
            break;
        case .received(let id):
            // need to notify client - fire event
            receiptsPublisher.send(.init(message: message, messageId: id));
            break;
        }
    }
    
    open func sendReceived(for message: Message) {
        guard let id = message.id, message.type != .groupchat, let jid = message.from else {
            return;
        }
        // need to send response/ack
        sendReceived(to: jid, forStanzaId: id, type: message.type)
    }
    
    open func sendReceived(to jid: JID, forStanzaId id: String, type: StanzaType?) {
        let response = Message();
        response.type = type;
        response.to = jid;
        response.messageDelivery = MessageDeliveryReceiptEnum.received(id: id);
        response.hints = [.store];
        write(response);
    }
    
    public struct Receipt {
        public let message: Message;
        public let messageId: String;
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
