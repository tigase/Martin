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
    public func subscribe(at pubSubJid: BareJID, to nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions? = nil, completionHandler: ((PubSubResult<PubSubSubscriptionElement>)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);

        let subscribe = Element(name: "subscribe");
        subscribe.attribute("node", newValue: nodeName);
        subscribe.attribute("jid", newValue: subscriber.description);
        pubsub.addChild(subscribe);
        
        if let options = options?.element(type: .submit, onlyModified: false) {
            let optionsEl = Element(name: "options");
            optionsEl.attribute("jid", newValue: subscriber.description);
            optionsEl.attribute("node", newValue: nodeName);
            optionsEl.addChild(options);
            pubsub.addChild(optionsEl);
        }
        
        write(iq, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.flatMap({ response in
                guard let subscriptionEl = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "subscription"), let subscription = PubSubSubscriptionElement(from: subscriptionEl) else {
                    return .failure(.undefined_condition);
                }
                return .success(subscription);
            }))
        });
    }
    
    /**
     Unsubscribe from node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter subscriber: jid of subscriber
     - parameter completionHandler: called when result is available
     */
    public func unsubscribe(at pubSubJid: BareJID, from nodeName: String, subscriber: JID, completionHandler: ((PubSubResult<Void>)->Void)?) {
        self.unsubscribe(at: pubSubJid, from: nodeName, subscriber: subscriber, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.map({ _ in Void() }));
        });
    }
    
    /**
     Subscribe from node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter subscriber: jid of subscriber
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func unsubscribe<Failure: Error>(at pubSubJid: BareJID, from nodeName: String, subscriber: JID, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let unsubscribe = Element(name: "unsubscribe");
        unsubscribe.attribute("node", newValue: nodeName);
        unsubscribe.attribute("jid", newValue: subscriber.description);
        pubsub.addChild(unsubscribe);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }

    /**
     Configure subscription for node
     - parameter at: jid of PubSub service
     - parameter for: node name
     - parameter subscriber: jid of subscriber
     - parameter with: configuration to apply
     - parameter completionHandler: called when result is available
     */
    public func configureSubscription(at pubSubJid: BareJID, for nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions, completionHandler: ((PubSubResult<Void>)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let optionsEl = Element(name: "options");
        optionsEl.attribute("jid", newValue: subscriber.description);
        optionsEl.attribute("node", newValue: nodeName);
        optionsEl.addChild(options.element(type: .submit, onlyModified: false));
        pubsub.addChild(optionsEl);
        
        write(iq, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.map { _ in Void() });
        });
    }

    /**
     Retrieve default configuration for subscription
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter completionHandler: called when result is available
     */
    public func retrieveDefaultSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String?, completionHandler: ((PubSubResult<PubSubSubscribeOptions>)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let optionsEl = Element(name: "default");
        optionsEl.attribute("node", newValue: nodeName);
        pubsub.addChild(optionsEl);
        
        write(iq, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.flatMap({ stanza in
                if let defaultEl = stanza.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "default"), let x = defaultEl.firstChild(name: "x", xmlns: "jabber:x:data"), let defaults = PubSubSubscribeOptions(element: x) {
                    return .success(defaults);
                }
                return .failure(.undefined_condition);
            }))
        });
    }

    /**
     Retrieve configuration of subscription
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter subscriber: subscriber jid
     - parameter completionHandler: called when response is available
     */
    public func retrieveSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String, subscriber: JID, completionHandler: ((PubSubResult<PubSubSubscribeOptions>)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let optionsEl = Element(name: "options");
        optionsEl.attribute("jid", newValue: subscriber.description);
        optionsEl.attribute("node", newValue: nodeName);
        pubsub.addChild(optionsEl);
        
        write(iq, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.flatMap({ stanza in
                guard let optionsEl = stanza.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "options"), let x = optionsEl.firstChild(name: "x", xmlns: "jabber:x:data"), let options = PubSubSubscribeOptions(element: x) else {
                    return .failure(.undefined_condition);
                }
                return .success(options);
            }))
        });
    }

    /**
     Retrieve items from node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter limit: limits results of the query
     - parameter completionHandler: called when result is available
     */
    public func retrieveItems(from pubSubJid: BareJID, for nodeName: String, limit: QueryLimit = .none, completionHandler: @escaping (PubSubRetrieveItemsResult)->Void) {
        retrieveItems(from: pubSubJid, for: nodeName, limit: limit, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap({ stanza in
                guard let pubsubEl = stanza.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS), let itemsEl = pubsubEl.firstChild(name: "items") else {
                    return .failure(.undefined_condition);
                }
                var items = Array<PubSubModule.Item>();
                for elem in itemsEl.children {
                    if let id = elem.attribute("id") {
                        items.append(PubSubModule.Item(id: id, payload: elem.children.first));
                    }
                }
                let rsm = RSM.Result(from: pubsubEl.firstChild(name: "set", xmlns: RSM.XMLNS));
                return .success(RetrievedItems(node: itemsEl.attribute("node") ?? nodeName, items: items, rsm: rsm));
            }))
        });
    }
    
    public enum QueryLimit {
        case none
        case rsm(RSM.Query)
        case lastItems(Int)
        case items(withIds: [String])
    }
    
    /**
     Retrieve items from node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter limit: limits results of the query
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func retrieveItems<Failure: Error>(from pubSubJid: BareJID, for nodeName: String, limit: QueryLimit = .none, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);

        let items = Element(name: "items");
        items.attribute("node", newValue: nodeName);
        pubsub.addChild(items);
        
        switch limit {
        case .none:
            break;
        case .items(let itemIds):
            itemIds.forEach { (itemId) in
                let item = Element(name: "item");
                item.attribute("id", newValue: itemId);
                items.addChild(item);
            }
        case .rsm(let rsm):
            pubsub.addChild(rsm.element());
        case .lastItems(let maxItems):
            items.attribute("max_items", newValue: String(maxItems));
        }
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Retrieve own subscriptions for node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter completionHandler: called when result is available
     */
    public func retrieveOwnSubscriptions(from pubSubJid: BareJID, for nodeName: String, completionHandler: @escaping (PubSubResult<[PubSubSubscriptionElement]>)->Void) {
        self.retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: PubSubModule.PUBSUB_XMLNS, completionHandler: completionHandler);
    }
        
    /**
     Retrieve own affiliations for node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter completionHandler: called when result is available
     */
    public func retrieveOwnAffiliations(from pubSubJid: BareJID, for nodeName: String?, completionHandler: @escaping (PubSubRetrieveAffiliationsResult)->Void) {
        self.retrieveAffiliations(from: pubSubJid, source: .own(node: nodeName), completionHandler: completionHandler);
    }
    
    public struct RetrievedItems {
        public let node: String;
        public let items: [PubSubModule.Item];
        public let rsm: RSM.Result?;
    }
}

public typealias PubSubRetrieveItemsResult = Result<PubSubModule.RetrievedItems,PubSubError>

// async-await support
extension PubSubModule {
    
    public func subscribe(at pubSubJid: BareJID, to nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions? = nil) async throws -> PubSubSubscriptionElement {
        return try await withUnsafeThrowingContinuation { continuation in
            subscribe(at: pubSubJid, to: nodeName, subscriber: subscriber, with: options, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func unsubscribe(at pubSubJid: BareJID, from nodeName: String, subscriber: JID, completionHandler: ((PubSubResult<Void>)->Void)?) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            unsubscribe(at: pubSubJid, from: nodeName, subscriber: subscriber, completionHandler: {  result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func configureSubscription(at pubSubJid: BareJID, for nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            configureSubscription(at: pubSubJid, for: nodeName, subscriber: subscriber, with: options, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func retrieveDefaultSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String?) async throws -> PubSubSubscribeOptions {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveDefaultSubscriptionConfiguration(from: pubSubJid, for: nodeName, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func retrieveSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String, subscriber: JID) async throws -> PubSubSubscribeOptions {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveSubscriptionConfiguration(from: pubSubJid, for: nodeName, subscriber: subscriber, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func retrieveItems(from pubSubJid: BareJID, for nodeName: String, limit: QueryLimit = .none) async throws -> PubSubModule.RetrievedItems {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveItems(from: pubSubJid, for: nodeName, limit: limit, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func retrieveOwnSubscriptions(from pubSubJid: BareJID, for nodeName: String) async throws -> [PubSubSubscriptionElement] {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveOwnSubscriptions(from: pubSubJid, for: nodeName, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func retrieveOwnAffiliations(from pubSubJid: BareJID, for nodeName: String?) async throws -> [PubSubAffiliationItem] {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveOwnAffiliations(from: pubSubJid, for: nodeName, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
}
