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
                
        self.createNode(at: pubSubJid, node: nodeName, with: configuration, callback: { stanza in
            guard let response = stanza else {
                completionHandler?(.failure(errorCondition: .remote_server_timeout, pubsubErrorCondition: nil, response: nil));
                return;
            }
            if response.type == .result, let node = response.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_XMLNS)?.findChild(name: "create")?.getAttribute("node") ?? nodeName {
                completionHandler?(.success(node));
            } else {
                completionHandler?(.failure(errorCondition: response.errorCondition ?? .undefined_condition, pubsubErrorCondition: nil, response: response));
            }
        });
    }

    /**
     Create new node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: option configuration for new node
     - parameter callback: called when response is received or request times out
     */
    public func createNode(at pubSubJid: BareJID, node nodeName: String?, with configuration: JabberDataElement? = nil, callback: ((Stanza?) -> Void)?) {
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
        
        self.context.writer?.write(iq, callback: callback);
    }
    
    /**
     Configure node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: configuration to apply for node
     - parameter completionHandler: called when result is available
     */
    public func configureNode(at pubSubJid: BareJID, node nodeName: String, with configuration: JabberDataElement, completionHandler: @escaping (PubSubNodeConfigurationResult)->Void) {
        configureNode(at: pubSubJid, node: nodeName, with: configuration, callback: { response in
            if response?.type == StanzaType.result {
                completionHandler(.success(Void()));
            } else {
                let pubsubErrorElem = response?.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                completionHandler(.failure(errorCondition: response?.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: pubsubErrorElem == nil ? nil : PubSubErrorCondition(rawValue: pubsubErrorElem!.name), response: response));
            }
        });
    }

    /**
     Configure node at PubSub service
     - parameter at: address of PubSub service
     - parameter node: name of node to create
     - parameter with: configuration to apply for node
     - parameter callback: called when response is received or request times out
     */
    public func configureNode(at pubSubJid: BareJID, node nodeName: String, with configuration: JabberDataElement, callback: ((Stanza?) -> Void)? = nil) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);
        
        let configure = Element(name: "configure");
        configure.setAttribute("node", value: nodeName);
        configure.addChild(configuration.submitableElement(type: .submit));
        pubsub.addChild(configure);
        
        self.context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retrieve default node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter onSuccess: called when request succeeds - passes response stanza and default node configuration
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func requestDefaultNodeConfiguration(from pubSubJid: BareJID, completionHandler: @escaping (PubSubRetrieveNodeConfigurationResult)->Void) {
        requestDefaultNodeConfiguration(from: pubSubJid, callback: { response in
            if let stanza = response, stanza.type == .result {
                guard let defaultConfigElem = stanza.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.findChild(name: "default")?.findChild(name: "x", xmlns: "jabber:x:data") else {
                    completionHandler(.failure(errorCondition: .undefined_condition, pubsubErrorCondition: nil, response: stanza));
                    return;
                }
                completionHandler(.success(JabberDataElement(from: defaultConfigElem)!));
            } else {
                let pubsubErrorElem = response?.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                completionHandler(.failure(errorCondition: response?.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: pubsubErrorElem == nil ? nil : PubSubErrorCondition(rawValue: pubsubErrorElem!.name), response: response));
            }
        });
    }

    /**
     Retrieve default node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter callback: called when response is received or request times out     
     */
    public func requestDefaultNodeConfiguration(from pubSubJid: BareJID, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        pubsub.addChild(Element(name: "default"));
        
        self.context.writer?.write(iq, callback: callback);
    }

    /**
     Retrieve node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter node: node to retrieve configuration
     - parameter completionHandler: called when result of the request is available
     */
    public func retrieveNodeConfiguration(from pubSubJid: BareJID, node: String, completionHandler: @escaping (PubSubRetrieveNodeConfigurationResult)->Void) {
        retrieveNodeConfiguration(from: pubSubJid, node: node, callback: { response in
            if response?.type == StanzaType.result {
                if let config = response?.findChild(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS)?.findChild(name: "configure")?.findChild(name: "x", xmlns: "jabber:x:data"), let form = JabberDataElement(from: config) {
                    completionHandler(.success(form));
                } else {
                    completionHandler(.failure(errorCondition: .undefined_condition, pubsubErrorCondition: .unsupported, response: nil));
                }
            } else {
                let pubsubErrorElem = response?.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                completionHandler(.failure(errorCondition: response?.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: pubsubErrorElem == nil ? nil : PubSubErrorCondition(rawValue: pubsubErrorElem!.name), response: response));
            }
        });
    }
    
    /**
     Retrieve node configuration from PubSub service
     - parameter from: address of PubSub service
     - parameter node: node to retrieve configuration
     - parameter callback: called when response is received or request times out
     */
    public func retrieveNodeConfiguration(from pubSubJid: BareJID, node: String, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        let configure = Element(name: "configure");
        configure.setAttribute("node", value: node);
        pubsub.addChild(configure);
        iq.addChild(pubsub);
        
        pubsub.addChild(Element(name: "default"));
        
        self.context.writer?.write(iq, callback: callback);
    }

    /**
     Delete node from PubSub service
     - parameter from: address of PubSub service
     - parameter node: name of node to delete
     - parameter completionHandler: called when result is available
     */
    public func deleteNode(from pubSubJid: BareJID, node nodeName: String, completionHandler: ((PubSubNodeDeletionResult)->Void)?) {
        self.deleteNode(from: pubSubJid, node: nodeName, callback: { stanza in
            guard let response = stanza else {
                completionHandler?(.failure(errorCondition: .remote_server_timeout, pubsubErrorCondition: nil, response: nil));
                return;
            }
            if response.type == .result || response.errorCondition == .item_not_found {
                completionHandler?(.success(nodeName));
            } else {
                completionHandler?(.failure(errorCondition: response.errorCondition ?? .undefined_condition, pubsubErrorCondition: nil, response: response));
            }
        });
    }
    
    /**
     Delete node from PubSub service
     - parameter from: address of PubSub service
     - parameter node: name of node to delete
     - parameter callback: called when response is received or request times out
     */
    public func deleteNode(from pubSubJid: BareJID, node nodeName: String, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        let delete = Element(name: "delete");
        delete.setAttribute("node", value: nodeName);
        pubsub.addChild(delete);
        
        self.context.writer?.write(iq, callback: callback);
    }
    
    /**
     Delete all items published to node
     - parameter at: address of PubSub service
     - parameter from: name of node to delete all items
     - parameter onSuccess: called when request succeeds - passes response stanza
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func purgeItems(at pubSubJid: BareJID, from nodeName: String, completionHandler: @escaping (PubSubResult<Void>)->Void ) {
        self.purgeItems(at: pubSubJid, from: nodeName, callback: { stanza in
            guard let response = stanza else {
                completionHandler(.failure(errorCondition: .remote_server_timeout, pubsubErrorCondition: nil, response: nil));
                return;
            }
            if response.type == .result || response.errorCondition == .item_not_found {
                completionHandler(.success(Void()));
            } else {
                completionHandler(.failure(errorCondition: response.errorCondition ?? .undefined_condition, pubsubErrorCondition: nil, response: response));
            }
        });
    }
    
    /**
     Delete all items published to node
     - parameter at: address of PubSub service
     - parameter from: name of node to delete all items
     - parameter callback: called when response is received or request times out
     */
    public func purgeItems(at pubSubJid: BareJID, from nodeName: String, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.set;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: PubSubModule.PUBSUB_OWNER_XMLNS);
        iq.addChild(pubsub);

        let purge = Element(name: "purge");
        purge.setAttribute("node", value: nodeName)
        pubsub.addChild(purge);
        
        self.context.writer?.write(iq, callback: callback);
    }
    
    /**
     Retrieve all subscriptions to node
     - parameter from: address of PubSub service
     - parameter for: name of node
     - parameter completionHandler: called when result is available
     */
    public func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String = PubSubModule.PUBSUB_OWNER_XMLNS, completionHandler: @escaping (PubSubResult<[PubSubSubscriptionElement]>)->Void) {
        self.retrieveSubscriptions(from: pubSubJid, for: nodeName, xmlns: xmlns, callback: { stanza in
            guard let response = stanza else {
                completionHandler(.failure(errorCondition: .remote_server_timeout, pubsubErrorCondition: nil, response: nil));
                return;
            }
            if response.type == .result {
                let subscriptions = response.findChild(name: "pubsub", xmlns: xmlns)?.findChild(name: "subscriptions")?.mapChildren(transform: PubSubSubscriptionElement.init(from: )) ?? [];
                completionHandler(.success(subscriptions));
            } else {
                completionHandler(.failure(errorCondition: response.errorCondition ?? .undefined_condition, pubsubErrorCondition: nil, response: response));
            }
        });
    }
    
    /**
     Retrieve all subscriptions to node
     - parameter from: address of PubSub service
     - parameter for: name of node
     - parameter callback: called when response is received or request times out
     */
    public func retrieveSubscriptions(from pubSubJid: BareJID, for nodeName: String, xmlns: String = PubSubModule.PUBSUB_OWNER_XMLNS, callback: ((Stanza?)->Void)?) {
        let iq = Iq();
        iq.type = StanzaType.get;
        iq.to = JID(pubSubJid);
        
        let pubsub = Element(name: "pubsub", xmlns: xmlns);
        iq.addChild(pubsub);
        
        let subscriptions = Element(name: "subscriptions");
        subscriptions.setAttribute("node", value: nodeName)
        pubsub.addChild(subscriptions);
        
        self.context.writer?.write(iq, callback: callback);
    }
 
    /**
     Set subscriptions for passed items for node
     - parameter at: address of PubSub service
     - parameter for: name of node
     - parameter subscriptions: array of subscription items to modify
     - parameter onSuccess: called when request succeeds - passes response stanza
     - parameter onError: called when request failed - passes general and detailed error condition if available
     */
    public func setSubscriptions(at pubSubJid: BareJID, for nodeName: String, subscriptions values: [PubSubSubscriptionElement], completionHandler: ((PubSubResult<Void>)->Void)?) {
        self.setSubscriptions(at: pubSubJid, for: nodeName, subscriptions: values, callback: { stanza in
            if stanza?.type == .result {
                completionHandler?(.success(Void()));
            } else {
                let pubsubErrorElem = stanza?.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                completionHandler?(.failure(errorCondition: stanza?.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: pubsubErrorElem == nil ? nil : PubSubErrorCondition(rawValue: pubsubErrorElem!.name), response: stanza));
            }
        });
    }
    
    /**
     Set subscriptions for passed items for node
     - parameter at: address of PubSub service
     - parameter for: name of node
     - parameter subscriptions: array of subscription items to modify
     - parameter callback: called when response is received or request times out
     */
    public func setSubscriptions(at pubSubJid: BareJID, for nodeName: String, subscriptions values: [PubSubSubscriptionElement], callback: ((Stanza?)->Void)?) {
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
        
        self.context.writer?.write(iq, callback: callback);
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
        
        self.context.writer?.write(iq, callback: { stanza in
            guard let response = stanza else {
                completionHandler(.failure(errorCondition: .remote_server_timeout, pubsubErrorCondition: nil, response: nil));
                return;
            }
            switch response.type ?? .error {
            case .result:
                guard let affiliationsEl = response.findChild(name: "pubsub", xmlns: xmlns)?.findChild(name: "affiliations") else {
                    completionHandler(.failure(errorCondition: .undefined_condition, pubsubErrorCondition: .unsupported, response: response));
                    return;
                }
                switch source {
                case .node(let node):
                    let affiliations = affiliationsEl.mapChildren(transform: { el in PubSubAffiliationItem(from: el, node: node) });
                    completionHandler(.success(affiliations));
                case .own:
                    let jid = response.to!.withoutResource;
                    let affiliations = affiliationsEl.mapChildren(transform: { el in PubSubAffiliationItem(from: el, jid: jid) });
                    completionHandler(.success(affiliations));
                }
            default:
                let pubsubError = response.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                completionHandler(.failure(errorCondition: response.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: pubsubError == nil ? nil : PubSubErrorCondition(rawValue: pubsubError!.name), response: response));
            }
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
        
        self.context.writer?.write(iq, callback: { stanza in
            guard let response = stanza else {
                completionHandler(.failure(errorCondition: .remote_server_timeout, pubsubErrorCondition: nil, response: nil));
                return;
            }
            switch response.type ?? .error {
            case .result:
                completionHandler(.success(Void()));
            default:
                let pubsubError = response.findChild(name: "error")?.findChild(xmlns: PubSubModule.PUBSUB_ERROR_XMLNS);
                completionHandler(.failure(errorCondition: response.errorCondition ?? .remote_server_timeout, pubsubErrorCondition: pubsubError == nil ? nil : PubSubErrorCondition(rawValue: pubsubError!.name), response: response));
            }
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
