//
// PubSubModule+Subscriber.swift
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

extension PubSubModule {

    /**
     Subscribe to node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter subscriber: jid of subscriber
     - parameter with: optional subscription options
     - parameter completionHandler: called when result is available
     */
    public func subscribe(at pubSubJid: BareJID, to nodeName: String, subscriber: JID, with options: JabberDataElement? = nil, completionHandler: ((PubSubResult<PubSubSubscriptionElement>)->Void)?) {
        
        self.subscribe(at: pubSubJid, to: nodeName, subscriber: subscriber, callback: { stanza in
            guard stanza?.type == .result, let subscriptionEl = stanza?.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "subscription"), let subscription = PubSubSubscriptionElement(from: subscriptionEl) else {
                completionHandler?(.failure(errorCondition: stanza?.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: nil, response: stanza));
                return;
            }
            completionHandler?(.success(subscription));
        });
    }

    /**
     Subscribe to node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter subscriber: jid of subscriber
     - parameter with: optional subscription options
     - parameter callback: called when response is received or request times out
     */
    public func subscribe(at pubSubJid: BareJID, to nodeName: String, subscriber: JID, with options: JabberDataElement? = nil, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);

        let subscribe = Element(name: "subscribe");
        subscribe.setAttribute("node", value: nodeName);
        subscribe.setAttribute("jid", value: subscriber.stringValue);
        pubsub.addChild(subscribe);
        
        if options != nil {
            let optionsEl = Element(name: "options");
            optionsEl.setAttribute("jid", value: subscriber.stringValue);
            optionsEl.setAttribute("node", value: nodeName);
            optionsEl.addChild(options!.element);
            pubsub.addChild(optionsEl);
        }
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Unsubscribe from node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter subscriber: jid of subscriber
     - parameter completionHandler: called when result is available
     */
    public func unsubscribe(at pubSubJid: BareJID, from nodeName: String, subscriber: JID, completionHandler: ((PubSubResult<Void>)->Void)?) {
        self.unsubscribe(at: pubSubJid, from: nodeName, subscriber: subscriber, callback: { stanza in
            if stanza?.type == .result {
                completionHandler?(.success(Void()));
            } else {
                completionHandler?(.failure(errorCondition: stanza?.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: nil, response: stanza));
            }
        });
    }
    
    /**
     Subscribe from node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter subscriber: jid of subscriber
     - parameter callback: called when response is received or request times out
     */
    public func unsubscribe(at pubSubJid: BareJID, from nodeName: String, subscriber: JID, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let unsubscribe = Element(name: "unsubscribe");
        unsubscribe.setAttribute("node", value: nodeName);
        unsubscribe.setAttribute("jid", value: subscriber.stringValue);
        pubsub.addChild(unsubscribe);
        
        context.writer?.write(iq, callback: callback);
    }

    /**
     Configure subscription for node
     - parameter at: jid of PubSub service
     - parameter for: node name
     - parameter subscriber: jid of subscriber
     - parameter with: configuration to apply
     - parameter onSuccess: called when request succeeds - passes response stanza
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func configureSubscription(at pubSubJid: BareJID, for nodeName: String, subscriber: JID, with options: JabberDataElement, completionHandler: ((PubSubResult<Void>)->Void)?) {
        self.configureSubscription(at: pubSubJid, for: nodeName, subscriber: subscriber, with: options, callback: { stanza in
            if stanza?.type == .result {
                completionHandler?(.success(Void()));
            } else {
                completionHandler?(.failure(errorCondition: stanza?.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: nil, response: stanza));
            }
        });
    }
    
    /**
     Configure subscription for node
     - parameter at: jid of PubSub service
     - parameter for: node name
     - parameter subscriber: jid of subscriber
     - parameter with: configuration to apply
     - parameter callback: called when response is received or request times out
     */
    public func configureSubscription(at pubSubJid: BareJID, for nodeName: String, subscriber: JID, with options: JabberDataElement, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let optionsEl = Element(name: "options");
        optionsEl.setAttribute("jid", value: subscriber.stringValue);
        optionsEl.setAttribute("node", value: nodeName);
        optionsEl.addChild(options.element);
        pubsub.addChild(optionsEl);
        
        context.writer?.write(iq, callback: callback);
    }

    /**
     Retrieve default configuration for subscription
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter completionHandler: called when result is available
     */
    public func retrieveDefaultSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String?, completionHandler: ((PubSubResult<JabberDataElement>)->Void)?) {
        self.retrieveDefaultSubscriptionConfiguration(from: pubSubJid, for: nodeName, callback: { response in
            if let stanza = response, stanza.type == .result,  let defaultEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "default"), let x = defaultEl.findChild(name: "x", xmlns: "jabber:x:data"), let defaults = JabberDataElement(from: x) {
                completionHandler?(.success(defaults));
                return;
            }
            completionHandler?(.failure(errorCondition: response?.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: nil, response: response));
        });
    }
    
    /**
     Retrieve default configuration for subscription
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter callback: called when response is received or request times out
     */
    public func retrieveDefaultSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String?, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let optionsEl = Element(name: "default");
        optionsEl.setAttribute("node", value: nodeName);
        pubsub.addChild(optionsEl);
        
        context.writer?.write(iq, callback: callback);
    }

    /**
     Retrieve configuration of subscription
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter subscriber: subscriber jid
     - parameter completionHandler: called when response is available
     */
    public func retrieveSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String, subscriber: JID, completionHandler: ((PubSubResult<JabberDataElement>)->Void)?) {
        self.retrieveSubscriptionConfiguration(from: pubSubJid, for: nodeName, subscriber: subscriber, callback: { response in
            guard let stanza = response, stanza.type == .result else {
                completionHandler?(.failure(errorCondition: .remote_server_timeout, pubsubErrorCondition: nil, response: nil));
                return;
            }
            guard let optionsEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "options"), let x = optionsEl.findChild(name: "x", xmlns: "jabber:x:data"), let options = JabberDataElement(from: x) else {
                completionHandler?(.failure(errorCondition: .undefined_condition, pubsubErrorCondition: nil, response: stanza));
                return;
            }
            completionHandler?(.success(options));
        });
    }
    
    /**
     Retrieve configuration of subscription
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter subscriber: subscriber jid
     - parameter callback: called when response is received or request times out
     */
    public func retrieveSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String, subscriber: JID, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let optionsEl = Element(name: "options");
        optionsEl.setAttribute("jid", value: subscriber.stringValue);
        optionsEl.setAttribute("node", value: nodeName);
        pubsub.addChild(optionsEl);
        
        context.writer?.write(iq, callback: callback);
    }

    /**
     Retrieve items from node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter rsm: result set information
     - parameter lastItem: number of last items to return
     - parameter itemIds: array of item ids to retrieve
     - parameter completionHandler: called when result is available
     */
    public func retrieveItems(from pubSubJid: BareJID, for nodeName: String, rsm: RSM.Query? = nil, lastItems: Int? = nil, itemIds: [String]? = nil, completionHandler: @escaping (PubSubRetrieveItemsResult)->Void) {
        retrieveItems(from: pubSubJid, for: nodeName, rsm: rsm, lastItems: lastItems, itemIds: itemIds, callback: { response in
            guard let stanza = response else {
                completionHandler(.failure(errorCondition: .remote_server_timeout, response: nil))
                return;
            }
            
            guard stanza.type != StanzaType.error else {
                let pubsubErrorElem = stanza.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                completionHandler(.failure(errorCondition: stanza.errorCondition ?? ErrorCondition.undefined_condition, pubsubErrorCondition: PubSubErrorCondition(rawValue: pubsubErrorElem?.name ?? ""), response: response));
                return;
            }
            
            let pubsubEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
            let itemsEl = pubsubEl?.findChild(name: "items");
            var items = Array<PubSubModule.Item>();
            itemsEl?.forEachChild { (elem) in
                if let id = elem.getAttribute("id") {
                    items.append(PubSubModule.Item(id: id, payload: elem.firstChild()));
                }
            }
            let rsm = RSM.Result(from: pubsubEl?.findChild(name: "set", xmlns: RSM.XMLNS));
            completionHandler(.success(response: stanza, node: itemsEl?.getAttribute("node") ?? nodeName, items: items, rsm: rsm));
        });
    }
    
    /**
     Retrieve items from node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter rsm: result set information
     - parameter lastItem: number of last items to return
     - parameter itemIds: array of item ids to retrieve
     - parameter callback: called when response is received or request times out
     */
    public func retrieveItems(from pubSubJid: BareJID, for nodeName: String, rsm: RSM.Query? = nil, lastItems: Int? = nil, itemIds: [String]? = nil, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);

        let items = Element(name: "items");
        items.setAttribute("node", value: nodeName);
        pubsub.addChild(items);
        
        if itemIds != nil {
            itemIds!.forEach { (itemId) in
                let item = Element(name: "item");
                item.setAttribute("id", value: itemId);
                items.addChild(item);
            }
        } else if rsm != nil {
            pubsub.addChild(rsm!.element);
        } else if lastItems != nil {
            items.setAttribute("max_items", value: String(lastItems!));
        }
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retrieve own subscriptions for node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter onSuccess: called when request succeeds - passes response stanza, array of subscription items
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func retrieveOwnSubscriptions(from pubSubJid: BareJID, for nodeName: String, completionHandler: @escaping (PubSubResult< [PubSubSubscriptionElement]>)->Void) {
        self.retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: PubSubModule.PUBSUB_XMLNS, completionHandler: completionHandler);
    }
    
    /**
     Retrieve own subscriptions for node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter callback: called when response is received or request times out
     */
    public func retrieveOwnSubscriptions(from pubSubJid: BareJID, for nodeName: String, callback: ((Stanza?)->Void)?) {
        self.retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: PubSubModule.PUBSUB_XMLNS, callback: callback);
    }
    
    /**
     Retrieve own affiliations for node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter completionHandler: called when response is received
     */
    public func retrieveOwnAffiliations(from pubSubJid: BareJID, for nodeName: String?, completionHandler: @escaping (PubSubRetrieveAffiliationsResult)->Void) {
        self.retrieveAffiliations(from: pubSubJid, source: .own(node: nodeName), completionHandler: completionHandler);
    }
    
}

public enum PubSubRetrieveItemsResult {
    case success(response: Stanza, node: String, items: [PubSubModule.Item], rsm: RSM.Result?)
    case failure(errorCondition: ErrorCondition, pubsubErrorCondition: PubSubErrorCondition? = nil, response: Stanza?)
}
