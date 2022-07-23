//
// PubSubModule.swift
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
import Combine

extension XmppModuleIdentifier {
    public static var pubsub: XmppModuleIdentifier<PubSubModule> {
        return PubSubModule.IDENTIFIER;
    }
}

/**
 Module provides support for [XEP-0060: Publish-Subscribe]
 
 [XEP-0060: Publish-Subscribe]: http://www.xmpp.org/extensions/xep-0060.html
 */
open class PubSubModule: XmppModuleBase, XmppStanzaProcessor {
    
    public static let PUBSUB_XMLNS = "http://jabber.org/protocol/pubsub";
    
    public static let PUBSUB_ERROR_XMLNS = PUBSUB_XMLNS + "#error";
    
    public static let PUBSUB_EVENT_XMLNS = PUBSUB_XMLNS + "#event";
    
    public static let PUBSUB_OWNER_XMLNS = PUBSUB_XMLNS + "#owner";
    
    public static let IDENTIFIER = XmppModuleIdentifier<PubSubModule>();
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = PUBSUB_XMLNS;
        
    public let criteria = Criteria.name("message").add(Criteria.name("event", xmlns: PUBSUB_EVENT_XMLNS));
    
    public let features = [String]();
    
    private let itemsEventsSender = PassthroughSubject<ItemNotification,Never>();
    public let itemsEvents: AnyPublisher<ItemNotification,Never>;
    private let nodesEventsSender = PassthroughSubject<NodeNotification,Never>();
    public let nodesEvents: AnyPublisher<NodeNotification,Never>;

    public override init() {
        itemsEvents = itemsEventsSender.eraseToAnyPublisher();
        nodesEvents = nodesEventsSender.eraseToAnyPublisher();
    }
    
    open func process(stanza: Stanza) throws {
        switch stanza {
        case let msg as Message:
            try process(message: msg);
        default:
            throw XMPPError(condition: .feature_not_implemented);
        }
    }
    
    /**
     Processes incoming message with PubSub events
     - parameter message: message to process
     */
    open func process(message: Message) throws {
        guard message.type != StanzaType.error, let event = message.firstChild(name: "event", xmlns: PubSubModule.PUBSUB_EVENT_XMLNS) else {
            return;
        }

        let timestamp = message.delay?.stamp ?? Date();
        
        if let itemsElem = event.firstChild(name: "items"), let nodeName = itemsElem.attribute("node") {
            for item in itemsElem.children {
                if let itemId = item.attribute("id") {
                    let payload = item.children.first;
                
                    switch item.name {
                    case "item":
                        itemsEventsSender.send(.init(message: message, node: nodeName, timestamp: timestamp, action: .published(Item(id: itemId, payload: payload))));
                    case "retract":
                        itemsEventsSender.send(.init(message: message, node: nodeName, timestamp: timestamp, action: .retracted(itemId)))
                    default:
                        break;
                    }
                }
            }
        }
        
        if let collectionElem = event.firstChild(name: "collection"), let nodeName = collectionElem.attribute("node") {
            for el in collectionElem.children {
                if let childNode = el.attribute("node") {
                    switch el.name {
                    case "associate":
                        nodesEventsSender.send(.init(message: message, node: nodeName, timestamp: timestamp, action: .childAssociated(childNode)))
                    case "dissociate":
                        nodesEventsSender.send(.init(message: message, node: nodeName, timestamp: timestamp, action: .childDisassociated(childNode)))
                    default:
                        break;
                    }
                }
            }
        }
        
        if let deleteElem = event.firstChild(name: "delete"), let nodeName = deleteElem.attribute("node") {
            nodesEventsSender.send(.init(message: message, node: nodeName, timestamp: timestamp, action: .deleted));
        }
        
    }
    
    public struct ItemNotification {
        public let message: Message;
        public let node: String;
        public let timestamp: Date;
        public let action: Action;

        public init(message: Message, node: String, timestamp: Date, action: Action) {
            self.message = message;
            self.node = node;
            self.timestamp = timestamp;
            self.action = action;
        }

        public enum Action {
            case published(Item)
            case retracted(String)
        }
    }

    public struct NodeNotification {
        public let message: Message;
        public let node: String;
        public let timestamp: Date;
        public let action: Action;
        
        public init(message: Message, node: String, timestamp: Date, action: Action) {
            self.message = message;
            self.node = node;
            self.timestamp = timestamp;
            self.action = action;
        }
        
        public enum Action {
            case deleted
            case childAssociated(String)
            case childDisassociated(String)
        }
    }
    
    /// Instace which contains item id and payload in single object
    public struct Item: CustomStringConvertible {
        
        /// Item id
        public let id: String;
        /// Item payload
        public let payload: Element?;
        
        public var description: String {
            return "[id: " + id + ", payload: " + (payload?.description ?? "nil") + "]";
        }
        
        public init(id: String, payload: Element?) {
            self.id = id;
            self.payload = payload;
        }
    }
}
