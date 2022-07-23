//
// PubSubModule+Owner.swift
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
     Create new node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: option configuration for new node
     */
    public func createNode(at pubSubJid: BareJID, node nodeName: String?, with configuration: PubSubNodeConfig? = nil) async throws -> String {
        let iq = Iq(type: .set, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS, {
                Element(name: "create", {
                    Attribute("node", value: nodeName)
                })
                if let configuration = configuration {
                    Element(name: "configure", {
                        configuration.element(type: .submit, onlyModified: true)
                    })
                }
            })
        })

        let response = try await write(iq: iq);
        guard let node = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "create")?.attribute("node") ?? nodeName else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        
        return node;
    }
    
    /**
     Configure node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: configuration to apply for node
     */
    public func configureNode(at pubSubJid: BareJID?, node nodeName: String, with configuration: PubSubNodeConfig) async throws {
        let iq = Iq(type: .set, to: pubSubJid?.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS, {
                Element(name: "configure", {
                    Attribute("node", value: nodeName)
                    configuration.element(type: .submit, onlyModified: true)
                })
            })
        });
        
        try await write(iq: iq);
    }
    
    /**
     Retrieve default node configuration from PubSub service
     - parameter from: address of PubSub service
     */
    public func requestDefaultNodeConfiguration(from pubSubJid: BareJID) async throws -> PubSubNodeConfig {
        let iq = Iq(type: .get, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS, {
                Element(name: "default")
            })
        });
        
        let response = try await write(iq: iq);
        guard let defaultConfigElem = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.firstChild(name: "default")?.firstChild(name: "x", xmlns: "jabber:x:data"), let config = PubSubNodeConfig(element: defaultConfigElem) else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        return config;
    }

    /**
     Retrieve node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter node: node to retrieve configuration
     */
    public func retrieveNodeConfiguration(from pubSubJid: BareJID?, node: String) async throws -> PubSubNodeConfig {
        let iq = Iq(type: .get, to: pubSubJid?.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS, {
                Element(name: "configure", {
                    Attribute("node", value: node)
                })
            })
        });
        
        let response = try await write(iq: iq);
        guard let formElem = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.firstChild(name: "configure")?.firstChild(name: "x", xmlns: "jabber:x:data"), let config = PubSubNodeConfig(element: formElem) else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        return config;
    }

    /**
     Delete node from PubSub service
     - parameter from: address of PubSub service
     - parameter node: name of node to delete
     */
    public func deleteNode(from pubSubJid: BareJID, node nodeName: String) async throws -> String {
        let iq = Iq(type: .set, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS, {
                Element(name: "delete", {
                    Attribute("node", value: nodeName)
                })
            })
        })
        
        do {
            try await write(iq: iq)
            return nodeName;
        } catch let error as XMPPError {
            guard error.condition == .item_not_found else {
                throw error;
            }
            return nodeName;
        }
    }
    
    /**
     Delete all items published to node
     - parameter at: address of PubSub service
     - parameter from: name of node to delete all items
     */
    public func purgeItems(at pubSubJid: BareJID, from nodeName: String) async throws {
        let iq = Iq(type: .set, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS, {
                Element(name: "purge", {
                    Attribute("node", value: nodeName)
                })
            })
        })
        
        try await write(iq: iq);
    }
    
    /**
     Retrieve all subscriptions to node
     - parameter from: address of PubSub service
     - parameter for: name of node
     */
    public func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String = PubSubModule.PUBSUB_OWNER_XMLNS) async throws -> [PubSubSubscriptionElement] {
        let iq = Iq(type: .get, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: xmlns, {
                Element(name: "subscriptions", {
                    Attribute("node", value: nodeName)
                })
            })
        })
        
        let response = try await write(iq: iq);
        return response.firstChild(name: "pubsub", xmlns: xmlns)?.firstChild(name: "subscriptions")?.compactMapChildren(PubSubSubscriptionElement.init(from:)) ?? [];
    }
 
    /**
     Set subscriptions for passed items for node
     - parameter at: address of PubSub service
     - parameter for: name of node
     - parameter subscriptions: array of subscription items to modify
     */
    public func setSubscriptions(at pubSubJid: BareJID, for nodeName: String, subscriptions values: [PubSubSubscriptionElement]) async throws {
        let iq = Iq(type: .set, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS, {
                Element(name: "subscriptions", {
                    Attribute("node", value: nodeName)
                    for sub in values {
                        sub.element
                    }
                })
            })
        })
        
        try await write(iq: iq);
    }
    
    /**
     Retrieve all affiliatons for node
     - parameter from: address of PubSub service
     - parameter node: defines if affiliations should be retrieved for sender or for node
     */
    public func retrieveAffiliations(from pubSubJid: BareJID, for nodeName: String) async throws -> [PubSubAffiliationItem] {
        return try await retrieveAffiliations(from: pubSubJid, source: .node(nodeName));
    }
    
    /**
     Retrieve all affiliatons for node or sender jid
     - parameter from: address of PubSub service
     - parameter source: defines if affiliations should be retrieved for sender or for node
     */
    public func retrieveAffiliations(from pubSubJid: BareJID, source: PubSubAffilicationsSource) async throws -> [PubSubAffiliationItem] {
        let iq = Iq(type: .get, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: source.xmlns, {
                Element(name: "affiliations", {
                    Attribute("node", value: source.node)
                })
            });
        });
        
        let response = try await write(iq: iq);
        guard let affiliationsEl = response.firstChild(name: "pubsub", xmlns: source.xmlns)?.firstChild(name: "affiliations") else {
            throw XMPPError(condition: .undefined_condition, stanza: response);
        }
        
        switch source {
        case .node(let node):
            return affiliationsEl.compactMapChildren({ el in PubSubAffiliationItem(from: el, node: node) });
        case .own:
            let jid = response.to!.withoutResource();
            return affiliationsEl.compactMapChildren({ el in PubSubAffiliationItem(from: el, jid: jid) });
        }
    }
    
    /**
     Set affiliations for passed items for node
     - parameter at: address of PubSub service
     - parameter for: node name
     - parameter affiliations: array of affiliation items to modify
     */
    public func setAffiliations(at pubSubJid: BareJID, for nodeName: String, affiliations values: [PubSubAffiliationItem]) async throws {
        let iq = Iq(type: .get, to: pubSubJid.jid(), {
            Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS, {
                Element(name: "affiliations", {
                    Attribute("node", value: nodeName)
                    for aff in values {
                        aff.element()
                    }
                })
            });
        });
        
        try await write(iq: iq);
    }
}

public enum PubSubAffilicationsSource {
    case node(String)
    case own(node: String? = nil)
    
    var xmlns: String {
        switch self {
        case .node(_):
            return PubSubModule.PUBSUB_OWNER_XMLNS;
        case .own(_):
            return PubSubModule.PUBSUB_XMLNS;
        }
    }
    
    var node: String? {
        switch self {
        case .own(let node):
            return node;
        case .node(let node):
            return node;
        }
    }
}

// async-await support
extension PubSubModule {
    
    public func createNode(at pubSubJid: BareJID, node nodeName: String?, with configuration: PubSubNodeConfig? = nil, completionHandler: @escaping (Result<String,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await createNode(at: pubSubJid, node: nodeName, with: configuration)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func configureNode(at pubSubJid: BareJID?, node nodeName: String, with configuration: PubSubNodeConfig, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await configureNode(at: pubSubJid, node: nodeName, with: configuration)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func requestDefaultNodeConfiguration(from pubSubJid: BareJID, completionHandler: @escaping (Result<PubSubNodeConfig,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await requestDefaultNodeConfiguration(from: pubSubJid)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func retrieveNodeConfiguration(from pubSubJid: BareJID?, node: String, completionHandler: @escaping (Result<PubSubNodeConfig,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retrieveNodeConfiguration(from: pubSubJid, node: node)))
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func deleteNode(from pubSubJid: BareJID, node nodeName: String, completionHandler: @escaping (Result<String,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await deleteNode(from: pubSubJid, node: nodeName)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func purgeItems(at pubSubJid: BareJID, from nodeName: String, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await purgeItems(at: pubSubJid, from: nodeName)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String = PubSubModule.PUBSUB_OWNER_XMLNS, completionHandler: @escaping (Result<[PubSubSubscriptionElement],XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: xmlns)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func setSubscriptions(at pubSubJid: BareJID, for nodeName: String, subscriptions values: [PubSubSubscriptionElement], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await setSubscriptions(at: pubSubJid, for: nodeName, subscriptions: values)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
        
    public func retrieveAffiliations(from pubSubJid: BareJID, for nodeName: String, completionHandler: @escaping (Result<[PubSubAffiliationItem],XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retrieveAffiliations(from: pubSubJid, for: nodeName)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func retrieveAffiliations(from pubSubJid: BareJID, source: PubSubAffilicationsSource, completionHandler: @escaping (Result<[PubSubAffiliationItem],XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await retrieveAffiliations(from: pubSubJid, source: source)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
    
    public func setAffiliations(at pubSubJid: BareJID, for nodeName: String, affiliations values: [PubSubAffiliationItem], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        Task {
            do {
                completionHandler(.success(try await setAffiliations(at: pubSubJid, for: nodeName, affiliations: values)));
            } catch {
                completionHandler(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }
        
}
