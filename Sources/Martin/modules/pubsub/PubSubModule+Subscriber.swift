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
     */
    public func subscribe(at pubSubJid: BareJID, to nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions? = nil) async throws -> PubSubSubscriptionElement {
        let iq = Iq(type: .set, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "subscribe", {
                    Attribute("node", value: nodeName)
                    Attribute("jid", value: subscriber.description)
                })
                if let options = options {
                    Element(name: "options", {
                        options.element(type: .submit, onlyModified: false)
                    })
                }
            })
        });
        
        let response = try await write(iq: iq);
        guard let subscriptionEl = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "subscription"), let subscription = PubSubSubscriptionElement(from: subscriptionEl) else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        return subscription;
    }
    
    /**
     Unsubscribe from node
     - parameter at: jid of PubSub service
     - parameter from: node name
     - parameter subscriber: jid of subscriber
     */
    public func unsubscribe(at pubSubJid: BareJID, from nodeName: String, subscriber: JID) async throws {
        let iq = Iq(type: .set, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "unsubscribe", {
                    Attribute("node", value: nodeName)
                    Attribute("jid", value: subscriber.description)
                })
            })
        })
        
        try await write(iq: iq)
    }

    /**
     Configure subscription for node
     - parameter at: jid of PubSub service
     - parameter for: node name
     - parameter subscriber: jid of subscriber
     - parameter with: configuration to apply
     */
    public func configureSubscription(at pubSubJid: BareJID, for nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions) async throws {
        let iq = Iq(type: .set, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "options", {
                    Attribute("node", value: nodeName)
                    Attribute("jid", value: subscriber.description)
                    options.element(type: .submit, onlyModified: false)
                })
            })
        })
        
        try await write(iq: iq);
    }
    
    /**
     Retrieve default configuration for subscription
     - parameter from: jid of PubSub service
     - parameter for: node name
     */
    public func retrieveDefaultSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String?) async throws -> PubSubSubscribeOptions {
        let iq = Iq(type: .get, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "default", {
                    Attribute("node", value: nodeName)
                })
            })
        })
        let response = try await write(iq: iq)
        guard let defaultEl = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "default"), let x = defaultEl.firstChild(name: "x", xmlns: "jabber:x:data"), let defaults = PubSubSubscribeOptions(element: x) else {
            throw XMPPError(condition: .undefined_condition, stanza: response)
        }
        
        return defaults;
    }

    /**
     Retrieve configuration of subscription
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter subscriber: subscriber jid
     */
    public func retrieveSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String, subscriber: JID) async throws -> PubSubSubscribeOptions {
        let iq = Iq(type: .get, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "options", {
                    Attribute("node", value: nodeName)
                    Attribute("jid", value: subscriber.description)
                })
            })
        })
        
        let response = try await write(iq: iq);
        guard let optionsEl = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "options"), let x = optionsEl.firstChild(name: "x", xmlns: "jabber:x:data"), let options = PubSubSubscribeOptions(element: x) else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        return options;
    }

    /**
     Retrieve items from node
     - parameter from: jid of PubSub service
     - parameter for: node name
     - parameter limit: limits results of the query
     */
    public func retrieveItems(from pubSubJid: BareJID, for nodeName: String, limit: QueryLimit = .none) async throws -> PubSubModule.RetrievedItems {
        let iq = Iq(type: .get, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "items", {
                    Attribute("node", value: nodeName)
                    if case let .items(itemIds) = limit {
                        for itemId in itemIds {
                            Element(name: "item", {
                                Attribute("id", value: itemId)
                            })
                        }
                    }
                    if case let .lastItems(maxItems) = limit {
                        Attribute("max_items", value: String(maxItems))
                    }
                })
                if case let .rsm(rsm) = limit {
                    rsm.element()
                }
            })
        });
        
        let response = try await write(iq: iq)
        guard let pubsubEl = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS), let itemsEl = pubsubEl.firstChild(name: "items") else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        let items: [PubSubModule.Item] = itemsEl.compactMapChildren({
            if let id = $0.attribute("id") {
                return PubSubModule.Item(id: id, payload: $0.children.first)
            } else {
                return nil
            }
        })
        let rsm = RSM.Result(from: pubsubEl.firstChild(name: "set", xmlns: RSM.XMLNS));
        return RetrievedItems(node: itemsEl.attribute("node") ?? nodeName, items: items, rsm: rsm);
    }
    
    public enum QueryLimit {
        case none
        case rsm(RSM.Query)
        case lastItems(Int)
        case items(withIds: [String])
    }
    
    /**
     Retrieve own subscriptions for node
     - parameter from: jid of PubSub service
     - parameter for: node name
     */
    public func retrieveOwnSubscriptions(from pubSubJid: BareJID, for nodeName: String) async throws -> [PubSubSubscriptionElement] {
        try await retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: PubSubModule.PUBSUB_XMLNS);
    }
        
    /**
     Retrieve own affiliations for node
     - parameter from: jid of PubSub service
     - parameter for: node name
     */
    public func retrieveOwnAffiliations(from pubSubJid: BareJID, for nodeName: String?) async throws -> [PubSubAffiliationItem] {
        return try await retrieveAffiliations(from: pubSubJid, source: .own(node: nodeName));
    }
    
    public struct RetrievedItems {
        public let node: String;
        public let items: [PubSubModule.Item];
        public let rsm: RSM.Result?;
    }
}

// async-await support
extension PubSubModule {
    
    public func subscribe(at pubSubJid: BareJID, to nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions? = nil, completionHandler: @escaping (Result<PubSubSubscriptionElement,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await subscribe(at: pubSubJid, to: nodeName, subscriber: subscriber, with: options)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func unsubscribe(at pubSubJid: BareJID, from nodeName: String, subscriber: JID, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await unsubscribe(at: pubSubJid, from: nodeName, subscriber: subscriber)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func configureSubscription(at pubSubJid: BareJID, for nodeName: String, subscriber: JID, with options: PubSubSubscribeOptions, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await configureSubscription(at: pubSubJid, for: nodeName, subscriber: subscriber, with: options)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func retrieveDefaultSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String?, completionHandler: @escaping (Result<PubSubSubscribeOptions,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retrieveDefaultSubscriptionConfiguration(from: pubSubJid, for: nodeName)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retrieveSubscriptionConfiguration(from pubSubJid: BareJID, for nodeName: String, subscriber: JID, completionHandler: @escaping (Result<PubSubSubscribeOptions,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retrieveSubscriptionConfiguration(from: pubSubJid, for: nodeName, subscriber: subscriber)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retrieveItems(from pubSubJid: BareJID, for nodeName: String, limit: QueryLimit = .none, completionHandler: @escaping (Result<RetrievedItems,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retrieveItems(from: pubSubJid, for: nodeName, limit: limit)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retrieveOwnSubscriptions(from pubSubJid: BareJID, for nodeName: String, completionHandler: @escaping (Result<[PubSubSubscriptionElement],XMPPError>)->Void) {
        self.retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: PubSubModule.PUBSUB_XMLNS, completionHandler: completionHandler);
    }

    public func retrieveOwnAffiliations(from pubSubJid: BareJID, for nodeName: String?, completionHandler: @escaping (Result<[PubSubAffiliationItem],XMPPError>)->Void) {
        self.retrieveAffiliations(from: pubSubJid, source: .own(node: nodeName), completionHandler: completionHandler);
    }
    
}
