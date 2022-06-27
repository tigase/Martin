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
     - parameter completionHandler: called when result is available
     */
    open func createNode(at pubSubJid: BareJID, node nodeName: String?, with configuration: PubSubNodeConfig? = nil, completionHandler: @escaping (Result<String,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let create = Element(name: "create");
        if nodeName != nil {
            create.attribute("node", newValue: nodeName);
        }
        pubsub.addChild(create);
        
        if let configuration = configuration {
            let configure = Element(name: "configure");
            configure.addChild(configuration.element(type: .submit, onlyModified: true));
            pubsub.addChild(configure);
        }
        
        write(iq: iq, completionHandler: { result in
            completionHandler(result.flatMap({ response in
                if let node = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.firstChild(name: "create")?.attribute("node") ?? nodeName {
                    return .success(node);
                } else {
                    return .failure(XMPPError(condition: .undefined_condition, stanza: response));
                }
            }))
        });
    }
    
    /**
     Configure node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: configuration to apply for node
     - parameter completionHandler: called when result is available
     */
    open func configureNode(at pubSubJid: BareJID?, node nodeName: String, with configuration: PubSubNodeConfig, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        if let jid = pubSubJid {
            iq.to = JID(jid);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);
        
        let configure = Element(name: "configure");
        configure.attribute("node", newValue: nodeName);
        configure.addChild(configuration.element(type: .submit, onlyModified: true));
        pubsub.addChild(configure);
        
        write(iq: iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }))
        });
    }
    
    /**
     Retrieve default node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter completionHandler: called when result is available
     */
    open func requestDefaultNodeConfiguration(from pubSubJid: BareJID, completionHandler: @escaping (Result<PubSubNodeConfig,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        pubsub.addChild(Element(name: "default"));
        
        write(iq: iq, completionHandler: { result in
            completionHandler(result.flatMap({ stanza in
                guard let defaultConfigElem = stanza.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.firstChild(name: "default")?.firstChild(name: "x", xmlns: "jabber:x:data"), let config = PubSubNodeConfig(element: defaultConfigElem) else {
                    return .failure(XMPPError(condition: .undefined_condition, stanza: stanza));
                }
                return .success(config);
            }))
        });
    }

    /**
     Retrieve node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter node: node to retrieve configuration
     - parameter completionHandler: called when result of the request is available
     */
    open func retrieveNodeConfiguration(from pubSubJid: BareJID?, node: String, completionHandler: @escaping (Result<PubSubNodeConfig,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        if let jid = pubSubJid {
            iq.to = JID(jid);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        let configure = Element(name: "configure");
        configure.attribute("node", newValue: node);
        pubsub.addChild(configure);
        iq.addChild(pubsub);
        
        pubsub.addChild(Element(name: "default"));
        
        write(iq: iq, completionHandler: { result in
            completionHandler(result.flatMap({ response in
                if let formElem = response.firstChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.firstChild(name: "configure")?.firstChild(name: "x", xmlns: "jabber:x:data"), let config = PubSubNodeConfig(element: formElem) {
                    return .success(config);
                } else {
                    return .failure(XMPPError(condition: .undefined_condition, stanza: response));
                }
            }))
        });
    }

    /**
     Delete node from PubSub service
     - parameter from: address of PubSub service
     - parameter node: name of node to delete
     - parameter completionHandler: called when result is available
     */
    public func deleteNode(from pubSubJid: BareJID, node nodeName: String, completionHandler: @escaping (Result<String,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        let delete = Element(name: "delete");
        delete.attribute("node", newValue: nodeName);
        pubsub.addChild(delete);
        
        write(iq: iq, completionHandler: { result in
            completionHandler(result.map({ _ in nodeName }).flatMapError({ error in
                guard error.condition == .item_not_found else {
                    return .failure(error);
                }
                return .success(nodeName);
            }));
        });
    }
    
    /**
     Delete all items published to node
     - parameter at: address of PubSub service
     - parameter from: name of node to delete all items
     - parameter completionHandler: called when result is available
     */
    public func purgeItems(at pubSubJid: BareJID, from nodeName: String, completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        let purge = Element(name: "purge");
        purge.attribute("node", newValue: nodeName)
        pubsub.addChild(purge);
        write(iq: iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    /**
     Retrieve all subscriptions to node
     - parameter from: address of PubSub service
     - parameter for: name of node
     - parameter completionHandler: called when result is available
     */
    public func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String = PubSubModule.PUBSUB_OWNER_XMLNS, completionHandler: @escaping (Result<[PubSubSubscriptionElement],XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: xmlns);
        iq.addChild(pubsub);
        
        let subscriptions = Element(name: "subscriptions");
        subscriptions.attribute("node", newValue: nodeName)
        pubsub.addChild(subscriptions);
        write(iq: iq, completionHandler: { result in
            completionHandler(result.map({ response in
                return response.firstChild(name: "pubsub", xmlns: xmlns)?.firstChild(name: "subscriptions")?.compactMapChildren(PubSubSubscriptionElement.init(from: )) ?? [];
            }))
        });
    }
 
    /**
     Set subscriptions for passed items for node
     - parameter at: address of PubSub service
     - parameter for: name of node
     - parameter subscriptions: array of subscription items to modify
     - parameter completionHandler: called when result is available
     */
    public func setSubscriptions(at pubSubJid: BareJID, for nodeName: String, subscriptions values: [PubSubSubscriptionElement], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);
        
        let subscriptions = Element(name: "subscriptions");
        subscriptions.attribute("node", newValue: nodeName)
        pubsub.addChild(subscriptions);
        
        subscriptions.addChildren(values.map({ $0.element }));

        write(iq: iq, completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    @discardableResult
    private func prepareAffiliationsEl(source: PubSubAffilicationsSource, pubsubEl: Element) -> Element {
        let affiliations = Element(name: "affiliations");
        switch source {
        case .node(let node):
            affiliations.attribute("node", newValue: node);
            pubsubEl.xmlns = "http://jabber.org/protocol/pubsub#owner";
        case .own(let node):
            pubsubEl.xmlns = "http://jabber.org/protocol/pubsub"
            if node != nil {
                affiliations.attribute("node", newValue: node);
            }
        }
        pubsubEl.addChild(affiliations);
        return affiliations;
    }

    /**
     Retrieve all affiliatons for node
     - parameter from: address of PubSub service
     - parameter node: defines if affiliations should be retrieved for sender or for node
     - parameter completionHandler: called when response if available
     */
    public func retrieveAffiliations(from pubSubJid: BareJID, for nodeName: String, completionHandler: @escaping (Result<[PubSubAffiliationItem],XMPPError>)->Void) {
        self.retrieveAffiliations(from: pubSubJid, source: .node(nodeName), completionHandler: completionHandler);
    }
    
    /**
     Retrieve all affiliatons for node or sender jid
     - parameter from: address of PubSub service
     - parameter source: defines if affiliations should be retrieved for sender or for node
     - parameter completionHandler: called when response if available
     */
    public func retrieveAffiliations(from pubSubJid: BareJID, source: PubSubAffilicationsSource, completionHandler: @escaping (Result<[PubSubAffiliationItem],XMPPError>)->Void) {

        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub");
        iq.addChild(pubsub);
        
        self.prepareAffiliationsEl(source: source, pubsubEl: pubsub);
        
        let xmlns = pubsub.xmlns!;
        
        write(iq: iq, completionHandler: { result in
            completionHandler(result.flatMap({ response in
                guard let affiliationsEl = response.firstChild(name: "pubsub", xmlns: xmlns)?.firstChild(name: "affiliations") else {
                    return .failure(.undefined_condition);
                }
                switch source {
                case .node(let node):
                    let affiliations = affiliationsEl.compactMapChildren({ el in PubSubAffiliationItem(from: el, node: node) });
                    return .success(affiliations);
                case .own:
                    let jid = response.to!.withoutResource;
                    let affiliations = affiliationsEl.compactMapChildren({ el in PubSubAffiliationItem(from: el, jid: jid) });
                    return .success(affiliations);
                }
            }));
        });
    }
    
    /**
     Set affiliations for passed items for node
     - parameter at: address of PubSub service
     - parameter for: node name
     - parameter affiliations: array of affiliation items to modify
     - parameter completionHandler: called when response is available
     */
    public func setAffiliations(at pubSubJid: BareJID, for nodeName: String, affiliations values: [PubSubAffiliationItem], completionHandler: @escaping (Result<Void,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);
        
        let affiliations = Element(name: "affiliations");
        affiliations.attribute("node", newValue: nodeName);
        pubsub.addChild(affiliations);
        
        values.forEach { (v) in
            affiliations.addChild(v.element());
        }
        
        write(iq: iq,  completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
}

public enum PubSubAffilicationsSource {
    case node(String)
    case own(node: String? = nil)
}

// async-await support
extension PubSubModule {
    
    public func createNode(at pubSubJid: BareJID, node nodeName: String?, with configuration: PubSubNodeConfig? = nil) async throws -> String {
        return try await withUnsafeThrowingContinuation { continuation in
            createNode(at: pubSubJid, node: nodeName, with: configuration, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func configureNode(at pubSubJid: BareJID?, node nodeName: String, with configuration: PubSubNodeConfig) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            configureNode(at: pubSubJid, node: nodeName, with: configuration, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func requestDefaultNodeConfiguration(from pubSubJid: BareJID) async throws -> PubSubNodeConfig {
        return try await withUnsafeThrowingContinuation { continuation in
            requestDefaultNodeConfiguration(from: pubSubJid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    public func retrieveNodeConfiguration(from pubSubJid: BareJID?, node: String) async throws -> PubSubNodeConfig {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveNodeConfiguration(from: pubSubJid, node: node, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func deleteNode(from pubSubJid: BareJID, node nodeName: String) async throws -> String {
        return try await withUnsafeThrowingContinuation { continuation in
            deleteNode(from: pubSubJid, node: nodeName, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func purgeItems(at pubSubJid: BareJID, from nodeName: String) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            purgeItems(at: pubSubJid, from: nodeName, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String = PubSubModule.PUBSUB_OWNER_XMLNS) async throws -> [PubSubSubscriptionElement] {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: xmlns, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func setSubscriptions(at pubSubJid: BareJID, for nodeName: String, subscriptions values: [PubSubSubscriptionElement]) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            setSubscriptions(at: pubSubJid, for: nodeName, subscriptions: values, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
        
    public func retrieveAffiliations(from pubSubJid: BareJID, for nodeName: String) async throws -> [PubSubAffiliationItem] {
        return try await withUnsafeThrowingContinuation { continuation in
            retrieveAffiliations(from: pubSubJid, for: nodeName, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func setAffiliations(at pubSubJid: BareJID, for nodeName: String, affiliations values: [PubSubAffiliationItem]) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            setAffiliations(at: pubSubJid, for: nodeName, affiliations: values, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
}
