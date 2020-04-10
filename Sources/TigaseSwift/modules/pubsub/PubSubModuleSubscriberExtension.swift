//
// PubSubModuleSubscriberExtension.swift
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

public protocol PubSubModuleSubscriberExtension: class, ContextAware {
    
    func createCallback(onSuccess: ((Stanza)->Void)?, onError: ((ErrorCondition?, PubSubErrorCondition?) -> Void)?) -> ((Stanza?)->Void)?;
    
    func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String, onSuccess: ((Stanza, [PubSubSubscriptionElement])->Void)?, onError: ((ErrorCondition?, PubSubErrorCondition?)->Void)?);
    func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String, callback: ((Stanza?)->Void)?);

    func retrieveAffiliations(from pubSubJid: BareJID, source: PubSubAffilicationsSource, completionHandler: @escaping ((PubSubRetrieveAffiliationsResult)->Void));
    
}

extension PubSubModuleSubscriberExtension {

    /**
     Subscribe to node
     - parameter at: jid of PubSub service
     - parameter to: node name
     - parameter subscriber: jid of subscriber
     - parameter with: optional subscription options
     - parameter onSuccess: called when request succeeds - passes response stanza and subscription item
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func subscribe(at pubSubJid: BareJID, to nodeName: String, subscriber: JID, with options: JabberDataElement? = nil, onSuccess: ((Stanza,PubSubSubscriptionElement)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let callback = createCallback(onSuccess: { (stanza) in
            let subscriptionEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "subscription");
            guard subscriptionEl != nil, let subscription = PubSubSubscriptionElement(from: subscriptionEl!) else {
                onError?(ErrorCondition.undefined_condition, PubSubErrorCondition.unsupported);
                return;
            }
            onSuccess?(stanza, subscription);
            }, onError: onError);
        
        self.subscribe(at: pubSubJid, to: nodeName, subscriber: subscriber, callback: callback);
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
     - parameter onSuccess: called when request succeeds - passes response stanza
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func unsubscribe(at pubSubJid: BareJID, from nodeName: String, subscriber: JID, onSuccess: ((Stanza)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let callback = createCallback(onSuccess: onSuccess, onError: onError);
        
        self.unsubscribe(at: pubSubJid, from: nodeName, subscriber: subscriber, callback: callback);
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
    public func configureSubscription(at pubSubJid: BareJID, for nodeName: String, subscriber: JID, with options: JabberDataElement, onSuccess: ((Stanza)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let callback = createCallback(onSuccess: onSuccess, onError: onError);
        
        self.configureSubscription(at: pubSubJid, for: nodeName, subscriber: subscriber, with: options, callback: callback);
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
     - parameter onSuccess: called when request succeeds - passes response stanza, node name and configuration
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func retrieveDefaultSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String?, onSuccess: ((Stanza,String?,JabberDataElement)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let callback = createCallback(onSuccess: { (stanza) in
            let defaultEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "default");
            let x = defaultEl?.findChild(name: "x", xmlns: "jabber:x:data");
            guard x != nil, let defaults = JabberDataElement(from: x!) else {
                onError?(ErrorCondition.undefined_condition, PubSubErrorCondition.unsupported);
                return;
            }
            onSuccess?(stanza, defaultEl?.getAttribute("node") ?? nodeName, defaults);
            }, onError: onError);
        
        self.retrieveDefaultSubscriptionConfiguration(from: pubSubJid, for: nodeName, callback: callback);
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
     - parameter onSuccess: called when request succeeds - passes response stanza, node name, subscriber jid and configuration
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func retrieveSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String, subscriber: JID, onSuccess: ((Stanza,String,JID,JabberDataElement)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
        let callback = createCallback(onSuccess: { (stanza) in
            let optionsEl = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "options");
            let x = optionsEl?.findChild(name: "x", xmlns: "jabber:x:data");
            guard x != nil, let options = JabberDataElement(from: x!) else {
                onError?(ErrorCondition.undefined_condition, PubSubErrorCondition.unsupported);
                return;
            }
            onSuccess?(stanza, optionsEl?.getAttribute("node") ?? nodeName, JID(optionsEl?.getAttribute("jid")) ?? subscriber, options);
            }, onError: onError);
        
        self.retrieveSubscriptionConfiguration(from: pubSubJid, for: nodeName, subscriber: subscriber, callback: callback);
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
     - parameter onSuccess: called when request succeeds - passes response stanza, node name, array of retrieved items and result set informations
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func retrieveItems(from pubSubJid: BareJID, for nodeName: String, rsm: RSM.Query? = nil, lastItems: Int? = nil, itemIds: [String]? = nil, onSuccess: ((Stanza,String,[PubSubModule.Item],RSM.Result?)->Void)?, onError: ((ErrorCondition?,PubSubErrorCondition?)->Void)?) {
    
        self.retrieveItems(from: pubSubJid, for: nodeName, rsm: rsm, lastItems: lastItems, itemIds: itemIds, completionHandler: { result in
            switch result {
            case .success(let response, let node, let items, let rsm):
                onSuccess?(response, node, items, rsm);
            case .failure(let errorCondition, let pubsubErrorCondition, let response):
                onError?(errorCondition, pubsubErrorCondition);
            }
        })
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
    public func retrieveOwnSubscriptions(from pubSubJid: BareJID, for nodeName: String, onSuccess: ((Stanza, [PubSubSubscriptionElement])->Void)?, onError: ((ErrorCondition?, PubSubErrorCondition?)->Void)?) {
        self.retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: PubSubModule.PUBSUB_XMLNS, onSuccess: onSuccess, onError: onError);
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
