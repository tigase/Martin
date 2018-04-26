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

/**
 Module provides support for [XEP-0060: Publish-Subscribe]
 
 [XEP-0060: Publish-Subscribe]: http://www.xmpp.org/extensions/xep-0060.html
 */
open class PubSubModule: XmppModule, ContextAware, PubSubModuleOwnerExtension, PubSubModulePublisherExtension, PubSubModuleSubscriberExtension {
    
    open static let PUBSUB_XMLNS = "http://jabber.org/protocol/pubsub";
    
    open static let PUBSUB_ERROR_XMLNS = PUBSUB_XMLNS + "#error";
    
    open static let PUBSUB_EVENT_XMLNS = PUBSUB_XMLNS + "#event";
    
    open static let PUBSUB_OWNER_XMLNS = PUBSUB_XMLNS + "#owner";
    /// ID of module for lookup in `XmppModulesManager`
    open static let ID = PUBSUB_XMLNS;
    
    open let id = PUBSUB_XMLNS;
    
    open var context: Context!;
    
    open let criteria = Criteria.name("message").add(Criteria.name("event", xmlns: PUBSUB_EVENT_XMLNS));
    
    open let features = [String]();
    
    public init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        switch stanza {
        case let msg as Message:
            try process(message: msg);
        default:
            throw ErrorCondition.bad_request;
        }
    }
    
    /**
     Processes incoming message with PubSub events
     - parameter message: message to process
     */
    open func process(message: Message) throws {
        guard let event = message.findChild(name: "event", xmlns: PubSubModule.PUBSUB_EVENT_XMLNS) else {
            return;
        }

        let timestamp = message.delay?.stamp ?? Date();
        
        if let itemsElem = event.findChild(name: "items") {
            let nodeName = itemsElem.getAttribute("node");
            itemsElem.getChildren().forEach { (item) in
                let type = item.name;
                let itemId = item.getAttribute("id");
                let payload = item.firstChild();
                
                context.eventBus.fire(NotificationReceivedEvent(sessionObject: context.sessionObject, message: message, nodeName: nodeName, itemId: itemId, payload: payload, timestamp: timestamp, itemType: type));
            }
        }
        
        if let collectionElem = event.findChild(name: "collection") {
            if let nodeName = collectionElem.getAttribute("node") {
                collectionElem.mapChildren(transform: { (el) -> NotificationCollectionChildrenChangedEvent? in
                    guard let childNode = el.getAttribute("node"), let action = NotificationCollectionChildrenChangedEvent.Action(rawValue: el.name) else {
                        return nil;
                    }
                    return NotificationCollectionChildrenChangedEvent(sessionObject: self.context.sessionObject, message: message, nodeName: nodeName, childNodeName: childNode, action: action, timestamp: timestamp);
                }, filter: { (el) -> Bool in
                    el.name == NotificationCollectionChildrenChangedEvent.Action.associate.rawValue || el.name == NotificationCollectionChildrenChangedEvent.Action.dissociate.rawValue;
                }).forEach { ev in
                    self.context.eventBus.fire(ev);
                }
            }
        }
        
        if let deleteElem = event.findChild(name: "delete") {
            if let nodeName = deleteElem.getAttribute("node") {
                self.context.eventBus.fire(NotificationNodeDeletedEvent(sessionObject: self.context.sessionObject, message: message, nodeName: nodeName));
            }
        }
        
    }
    

    /**
     Helper function for creation of callbacks for requests executed by PubSubModule
     - parameter onSuccess: callback to execute when request returns success
     - parameter onError: callback to execute when request fails
     */
    open func createCallback(onSuccess: ((Stanza)->Void)?, onError: ((ErrorCondition?, PubSubErrorCondition?) -> Void)?) -> ((Stanza?)->Void)? {
        return { (stanza: Stanza?) -> Void in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
                case .result:
                onSuccess?(stanza!);
            default:
                let errorCondition = stanza?.errorCondition;
                let pubsubErrorElem = stanza?.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                onError?(errorCondition, pubsubErrorElem == nil ? nil : PubSubErrorCondition(rawValue: pubsubErrorElem!.name));
            }
        };
    }
    
    /// Event fired when received message with PubSub notification/event with items
    open class NotificationReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = NotificationReceivedEvent();
        
        open let type = "PubSubNotificationReceivedEvent"
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Received message with notification
        open let message: Message!;
        /// Name of node which sent notification
        open let nodeName: String?;
        /// Id of item
        open let itemId: String?;
        /// Type of item (action)
        open let itemType: String!;
        /// Item content - payload
        open let payload: Element?;
        /// Timestamp of event (may not be current if delivery was delayed on server side)
        open let timestamp: Date!;
        
        init() {
            self.sessionObject = nil;
            self.message = nil;
            self.nodeName = nil;
            self.itemId = nil;
            self.itemType = nil;
            self.payload = nil;
            self.timestamp = nil;
        }
        
        init(sessionObject: SessionObject, message: Message, nodeName: String?, itemId: String?, payload: Element?, timestamp: Date, itemType: String) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.nodeName = nodeName;
            self.itemId = itemId;
            self.itemType = itemType;
            self.payload = payload;
            self.timestamp = timestamp;
        }
        
    }
    
    open class NotificationCollectionChildrenChangedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = NotificationCollectionChildrenChangedEvent();

        open let type = "NotificationCollectionChildrenChangedEvent"
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Received message with notification
        open let message: Message!;
        /// Name of node which sent notification
        open let nodeName: String!;
        /// Name of child node
        open let childNodeName: String!;
        /// Action
        open let action: Action!;
        /// Timestamp of event (may not be current if delivery was delayed on server side)
        open let timestamp: Date!;

        init() {
            self.sessionObject = nil;
            self.message = nil;
            self.nodeName = nil;
            self.childNodeName = nil;
            self.action = nil;
            self.timestamp = nil;
        }
        
        init(sessionObject: SessionObject, message: Message, nodeName: String, childNodeName: String, action: Action, timestamp: Date) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.nodeName = nodeName;
            self.childNodeName = childNodeName;
            self.action = action;
            self.timestamp = timestamp;
        }

        public enum Action: String {
            case associate
            case dissociate
        }
    }
    
    open class NotificationNodeDeletedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = NotificationNodeDeletedEvent();
        
        open let type = "NotificationNodeDeletedEvent"
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject: SessionObject!;
        /// Received message with notification
        open let message: Message!;
        /// Name of node which sent notification
        open let nodeName: String!;
        
        init() {
            self.sessionObject = nil;
            self.message = nil;
            self.nodeName = nil;
        }
        
        init(sessionObject: SessionObject, message: Message, nodeName: String) {
            self.sessionObject = sessionObject;
            self.message = message;
            self.nodeName = nodeName;
        }
        
    }

    /// Instace which contains item id and payload in single object
    open class Item: CustomStringConvertible {
        
        /// Item id
        open let id: String;
        /// Item payload
        open let payload: Element;
        
        open var description: String {
            return "[id: " + id + ", payload: " + payload.stringValue + "]";
        }
        
        public init(id: String, payload: Element) {
            self.id = id;
            self.payload = payload;
        }
    }
}

