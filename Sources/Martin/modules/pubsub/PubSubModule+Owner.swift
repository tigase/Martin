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
    public func createNode(at pubSubJid: BareJID, node nodeName: String?, with configuration: JabberDataElement? = nil, completionHandler: ((PubSubNodeCreationResult)->Void)?) {
                
        self.createNode(at: pubSubJid, node: nodeName, with: configuration, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.flatMap({ response in
                if let node = response.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "create")?.getAttribute("node") ?? nodeName {
                    return .success(node);
                } else {
                    return .failure(.undefined_condition);
                }
            }))
        });
    }

    /**
     Create new node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: option configuration for new node
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func createNode<Failure: Error>(at pubSubJid: BareJID, node nodeName: String?, with configuration: JabberDataElement? = nil, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS);
        iq.addChild(pubsub);
        
        let create = Element(name: "create");
        if nodeName != nil {
            create.setAttribute("node", value: nodeName);
        }
        pubsub.addChild(create);
        
        if configuration != nil {
            let configure = Element(name: "configure");
            configure.addChild(configuration!.submitableElement(type: .submit));
            pubsub.addChild(configure);
        }
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Configure node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: configuration to apply for node
     - parameter completionHandler: called when result is available
     */
    public func configureNode(at pubSubJid: BareJID?, node nodeName: String, with configuration: JabberDataElement, completionHandler: @escaping (PubSubNodeConfigurationResult)->Void) {
        configureNode(at: pubSubJid, node: nodeName, with: configuration, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }

    /**
     Configure node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: configuration to apply for node
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func configureNode<Failure: Error>(at pubSubJid: BareJID?, node nodeName: String, with configuration: JabberDataElement, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        if let jid = pubSubJid {
            iq.to = JID(jid);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);
        
        let configure = Element(name: "configure");
        configure.setAttribute("node", value: nodeName);
        configure.addChild(configuration.submitableElement(type: .submit));
        pubsub.addChild(configure);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Retrieve default node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter completionHandler: called when result is available
     */
    public func requestDefaultNodeConfiguration(from pubSubJid: BareJID, completionHandler: @escaping (PubSubRetrieveNodeConfigurationResult)->Void) {
        requestDefaultNodeConfiguration(from: pubSubJid, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap { stanza in
                guard let defaultConfigElem = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.findChild(name: "default")?.findChild(name: "x", xmlns: "jabber:x:data"), let form = JabberDataElement(from: defaultConfigElem) else {
                    return .failure(.undefined_condition)
                }
                return .success(form);
            });
        });
    }

    /**
     Retrieve default node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func requestDefaultNodeConfiguration<Failure: Error>(from pubSubJid: BareJID, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        pubsub.addChild(Element(name: "default"));
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }

    /**
     Retrieve node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter node: node to retrieve configuration
     - parameter completionHandler: called when result of the request is available
     */
    public func retrieveNodeConfiguration(from pubSubJid: BareJID?, node: String, completionHandler: @escaping (PubSubRetrieveNodeConfigurationResult)->Void) {
        retrieveNodeConfiguration(from: pubSubJid, node: node, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.flatMap({ response in
                if let config = response.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.findChild(name: "configure")?.findChild(name: "x", xmlns: "jabber:x:data"), let form = JabberDataElement(from: config) {
                    return .success(form);
                } else {
                    return .failure(.undefined_condition);
                }
            }))
        });
    }
    
    /**
     Retrieve node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter node: node to retrieve configuration
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func retrieveNodeConfiguration<Failure: Error>(from pubSubJid: BareJID?, node: String, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        if let jid = pubSubJid {
            iq.to = JID(jid);
        }
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        let configure = Element(name: "configure");
        configure.setAttribute("node", value: node);
        pubsub.addChild(configure);
        iq.addChild(pubsub);
        
        pubsub.addChild(Element(name: "default"));
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }

    /**
     Delete node from PubSub service
     - parameter from: address of PubSub service
     - parameter node: name of node to delete
     - parameter completionHandler: called when result is available
     */
    public func deleteNode(from pubSubJid: BareJID, node nodeName: String, completionHandler: ((PubSubNodeDeletionResult)->Void)?) {
        self.deleteNode(from: pubSubJid, node: nodeName, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.map({ _ in nodeName }).flatMapError({ (error: PubSubError) in
                guard error.error == .item_not_found else {
                    return .failure(error);
                }
                return .success(nodeName);
            }));
        });
    }
    
    /**
     Delete node from PubSub service
     - parameter from: address of PubSub service
     - parameter node: name of node to delete
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func deleteNode<Failure: Error>(from pubSubJid: BareJID, node nodeName: String, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        let delete = Element(name: "delete");
        delete.setAttribute("node", value: nodeName);
        pubsub.addChild(delete);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Delete all items published to node
     - parameter at: address of PubSub service
     - parameter from: name of node to delete all items
     - parameter completionHandler: called when result is available
     */
    public func purgeItems(at pubSubJid: BareJID, from nodeName: String, completionHandler: @escaping (PubSubResult<Void>)->Void) {
        self.purgeItems(at: pubSubJid, from: nodeName, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
    
    /**
     Delete all items published to node
     - parameter at: address of PubSub service
     - parameter from: name of node to delete all items
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func purgeItems<Failure: Error>(at pubSubJid: BareJID, from nodeName: String, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        let purge = Element(name: "purge");
        purge.setAttribute("node", value: nodeName)
        pubsub.addChild(purge);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Retrieve all subscriptions to node
     - parameter from: address of PubSub service
     - parameter for: name of node
     - parameter completionHandler: called when result is available
     */
    public func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String = PubSubModule.PUBSUB_OWNER_XMLNS, completionHandler: @escaping (PubSubResult<[PubSubSubscriptionElement]>)->Void) {
        self.retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: xmlns, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler(result.map({ response in
                return response.findChild(name: "pubsub", xmlns: xmlns)?.findChild(name: "subscriptions")?.mapChildren(transform: PubSubSubscriptionElement.init(from: )) ?? [];
            }))
        });
    }
    
    /**
     Retrieve all subscriptions to node
     - parameter from: address of PubSub service
     - parameter for: name of node
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func retrieveSubscriptions<Failure: Error>(from pubSubJid: BareJID, for nodeName: String, xmlns: String = PubSubModule.PUBSUB_OWNER_XMLNS, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: xmlns);
        iq.addChild(pubsub);
        
        let subscriptions = Element(name: "subscriptions");
        subscriptions.setAttribute("node", value: nodeName)
        pubsub.addChild(subscriptions);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
 
    /**
     Set subscriptions for passed items for node
     - parameter at: address of PubSub service
     - parameter for: name of node
     - parameter subscriptions: array of subscription items to modify
     - parameter completionHandler: called when result is available
     */
    public func setSubscriptions(at pubSubJid: BareJID, for nodeName: String, subscriptions values: [PubSubSubscriptionElement], completionHandler: ((PubSubResult<Void>)->Void)?) {
        self.setSubscriptions(at: pubSubJid, for: nodeName, subscriptions: values, errorDecoder: PubSubError.from(stanza:), completionHandler: { result in
            completionHandler?(result.map({ _ in Void() }));
        });
    }
    
    /**
     Set subscriptions for passed items for node
     - parameter at: address of PubSub service
     - parameter for: name of node
     - parameter subscriptions: array of subscription items to modify
     - parameter errorDecoder: functon called to preprocess received stanza when error occurred
     - parameter completionHandler: called when result is available
     */
    public func setSubscriptions<Failure: Error>(at pubSubJid: BareJID, for nodeName: String, subscriptions values: [PubSubSubscriptionElement], errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);
        
        let subscriptions = Element(name: "subscriptions");
        subscriptions.setAttribute("node", value: nodeName)
        pubsub.addChild(subscriptions);
        
        values.forEach { (v) in
            subscriptions.addChild(v.element);
        }
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    @discardableResult
    private func prepareAffiliationsEl(source: PubSubAffilicationsSource, pubsubEl: Element) -> Element {
        let affiliations = Element(name: "affiliations");
        switch source {
        case .node(let node):
            affiliations.setAttribute("node", value: node);
            pubsubEl.xmlns = "http://jabber.org/protocol/pubsub#owner";
        case .own(let node):
            pubsubEl.xmlns = "http://jabber.org/protocol/pubsub"
            if node != nil {
                affiliations.setAttribute("node", value: node);
            }
        }
        pubsubEl.addNode(affiliations);
        return affiliations;
    }

    /**
     Retrieve all affiliatons for node
     - parameter from: address of PubSub service
     - parameter node: defines if affiliations should be retrieved for sender or for node
     - parameter completionHandler: called when response if available
     */
    public func retrieveAffiliations(from pubSubJid: BareJID, for nodeName: String, completionHandler: @escaping (PubSubRetrieveAffiliationsResult)->Void) {
        self.retrieveAffiliations(from: pubSubJid, source: .node(nodeName), completionHandler: completionHandler);
    }
    
    /**
     Retrieve all affiliatons for node or sender jid
     - parameter from: address of PubSub service
     - parameter source: defines if affiliations should be retrieved for sender or for node
     - parameter completionHandler: called when response if available
     */
    public func retrieveAffiliations(from pubSubJid: BareJID, source: PubSubAffilicationsSource, completionHandler: @escaping (PubSubRetrieveAffiliationsResult)->Void) {

        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub");
        iq.addChild(pubsub);
        
        self.prepareAffiliationsEl(source: source, pubsubEl: pubsub);
        
        let xmlns = pubsub.xmlns!;
        
        write(iq, errorDecoder: PubSubError.from(stanza: ), completionHandler: { result in
            completionHandler(result.flatMap({ response in
                guard let affiliationsEl = response.findChild(name: "pubsub", xmlns: xmlns)?.findChild(name: "affiliations") else {
                    return .failure(.undefined_condition);
                }
                switch source {
                case .node(let node):
                    let affiliations = affiliationsEl.mapChildren(transform: { el in PubSubAffiliationItem(from: el, node: node) });
                    return .success(affiliations);
                case .own:
                    let jid = response.to!.withoutResource;
                    let affiliations = affiliationsEl.mapChildren(transform: { el in PubSubAffiliationItem(from: el, jid: jid) });
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
    public func setAffiliations(at pubSubJid: BareJID, for nodeName: String, affiliations values: [PubSubAffiliationItem], completionHandler: @escaping (PubSubSetAffiliationsResult)->Void) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);
        
        let affiliations = Element(name: "affiliations");
        affiliations.setAttribute("node", value: nodeName);
        pubsub.addChild(affiliations);
        
        values.forEach { (v) in
            affiliations.addChild(v.element());
        }
        
        write(iq, errorDecoder: PubSubError.from(stanza: ), completionHandler: { result in
            completionHandler(result.map({ _ in Void() }));
        });
    }
}

public enum PubSubAffilicationsSource {
    case node(String)
    case own(node: String? = nil)
}

public typealias PubSubRetrieveAffiliationsResult = PubSubResult<[PubSubAffiliationItem]>
public typealias PubSubSetAffiliationsResult = PubSubResult<Void>;
public typealias PubSubNodeCreationResult = PubSubResult<String>;
public typealias PubSubNodeDeletionResult = PubSubResult<String>;
public typealias PubSubNodeConfigurationResult = PubSubResult<Void>;
public typealias PubSubRetrieveNodeConfigurationResult = PubSubResult<JabberDataElement>;

// async-await support
extension PubSubModule {
    
    public func createNode(at pubSubJid: BareJID, node nodeName: String?, with configuration: JabberDataElement? = nil) async throws -> String {
        return try await withUnsafeThrowingContinuation { continuation in
            createNode(at: pubSubJid, node: nodeName, with: configuration, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func configureNode(at pubSubJid: BareJID?, node nodeName: String, with configuration: JabberDataElement, errorDecoder: @escaping PacketErrorDecoder<Error> = PubSubError.from(stanza:)) async throws -> Iq {
        return try await withUnsafeThrowingContinuation { continuation in
            configureNode(at: pubSubJid, node: nodeName, with: configuration, errorDecoder: errorDecoder, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    public func requestDefaultNodeConfiguration(from pubSubJid: BareJID) async throws -> JabberDataElement {
        return try await withUnsafeThrowingContinuation { continuation in
            requestDefaultNodeConfiguration(from: pubSubJid, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }

    public func retrieveNodeConfiguration(from pubSubJid: BareJID?, node: String) async throws -> JabberDataElement {
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

