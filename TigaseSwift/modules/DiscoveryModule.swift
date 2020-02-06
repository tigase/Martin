//
// DiscoveryModule.swift
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
 Module responsible for [XEP-0030: Service Discovery] feature.
 
 [XEP-0030: Service Discovery]: http://xmpp.org/extensions/xep-0030.html
 */
open class DiscoveryModule: Logger, AbstractIQModule, ContextAware {

    /**
     Property name under which category of XMPP entity is hold for returning
     to remote clients on query
     */
    public static let IDENTITY_CATEGORY_KEY = "discoveryIdentityCategory";
    /** 
     Property name under which type of XMPP entity is hold for returning 
     to remote clients on query
     */
    public static let IDENTITY_TYPE_KEY = "discoveryIdentityType";
    /// Namespace used by service discovery
    public static let ITEMS_XMLNS = "http://jabber.org/protocol/disco#items";
    /// Namespace used by service discovery
    public static let INFO_XMLNS = "http://jabber.org/protocol/disco#info";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "discovery";
    
    public static let SERVER_IDENTITY_TYPES_KEY = "serverIdentityTypes";
    public static let SERVER_FEATURES_KEY = "serverFeatures";
    
    public static let ACCOUNT_IDENTITY_TYPES_KEY = "accountIdentityTypes";
    public static let ACCOUNT_FEATURES_KEY = "accountFeatures";
    
    public let id = ID;
    
    open var context:Context!;
    
    public let criteria = Criteria.name("iq").add(
        Criteria.or(
            Criteria.name("query", xmlns: DiscoveryModule.ITEMS_XMLNS),
            Criteria.name("query", xmlns: DiscoveryModule.INFO_XMLNS)
        )
    );
    
    public let features = [ DiscoveryModule.ITEMS_XMLNS, DiscoveryModule.INFO_XMLNS ];
    
    fileprivate var callbacks = [String:NodeDetailsEntry]();
    
    public override init() {
        super.init()
        setNodeCallback(nil, entry: NodeDetailsEntry(
            identity: { (sessionObject: SessionObject, stanza: Stanza, node: String?) -> Identity? in
                return Identity(category: sessionObject.getProperty(DiscoveryModule.IDENTITY_CATEGORY_KEY, defValue: "client"),
                    type: sessionObject.getProperty(DiscoveryModule.IDENTITY_TYPE_KEY, defValue: "pc"),
                    name: sessionObject.getProperty(SoftwareVersionModule.NAME_KEY, defValue: SoftwareVersionModule.DEFAULT_NAME_VAL)
                );
            },
            features: { (sessionObject: SessionObject, stanza: Stanza, node: String?) -> [String]? in
                return Array(self.context.modulesManager.availableFeatures);
            },
            items: { (sessionObject: SessionObject, stanza: Stanza, node: String?) -> [Item]? in
                return nil;
            }
        ));
    }
    
    /**
     Method sends query to server to discover server features
     - parameter onInfoReceived: called when info will be available
     - parameter onError: called when received error or request timed out
     */
    open func discoverServerFeatures(onInfoReceived:((_ node: String?, _ identities: [Identity], _ features: [String]) -> Void)?, onError: ((_ errorCondition: ErrorCondition?) -> Void)?) {
        if let jid = ResourceBinderModule.getBindedJid(context.sessionObject) {
            getInfo(for: JID(jid.domain), onInfoReceived: {(node :String?, identities: [Identity], features: [String]) -> Void in
                self.context.sessionObject.setProperty(DiscoveryModule.SERVER_IDENTITY_TYPES_KEY, value: identities);
                self.context.sessionObject.setProperty(DiscoveryModule.SERVER_FEATURES_KEY, value: features)
                self.context.eventBus.fire(ServerFeaturesReceivedEvent(sessionObject: self.context.sessionObject, features: features, identities: identities));
                onInfoReceived?(node, identities, features);
                }, onError: onError);
        }
    }
    
    /**
     Method sends query to the account bare jid to discover server features handled on behalf of the user
     - parameter onInfoReceived: called when info will be available
     - parameter onError: called when received error or request timed out
     */
    open func discoverAccountFeatures(onInfoReceived:((_ node: String?, _ identities: [Identity], _ features: [String]) -> Void)?, onError: ((_ errorCondition: ErrorCondition?) -> Void)?) {
        if let jid = ResourceBinderModule.getBindedJid(context.sessionObject) {
            getInfo(for: jid.withoutResource, onInfoReceived: {(node :String?, identities: [Identity], features: [String]) -> Void in
                self.context.sessionObject.setProperty(DiscoveryModule.ACCOUNT_IDENTITY_TYPES_KEY, value: identities);
                self.context.sessionObject.setProperty(DiscoveryModule.ACCOUNT_FEATURES_KEY, value: features)
                self.context.eventBus.fire(AccountFeaturesReceivedEvent(sessionObject: self.context.sessionObject, features: features));
                onInfoReceived?(node, identities, features);
            }, onError: onError);
        }
    }
    
    /**
     Method retieves informations about particular XMPP recipient and it's node
     - parameter for: recipient to query
     - parameter node: node to query for informations
     - parameter callback: called on result or failure
     */
    open func getInfo(for jid: JID, node: String?, callback: @escaping (Stanza?) -> Void) {
        let iq = Iq();
        iq.to  = jid;
        iq.type = StanzaType.get;
        let query = Element(name: "query", xmlns: DiscoveryModule.INFO_XMLNS);
        if node != nil {
            query.setAttribute("node", value: node);
        }
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }
    
    /**
     Method retieves informations about particular XMPP recipient and it's node
     - parameter for: recipient to query
     - parameter node: node to query for informations
     - parameter onInfoReceived: called where response with result is received
     - parameter onError: called when received error or request timed out
     */
    open func getInfo(for jid:JID, node requestedNode:String? = nil, onInfoReceived:@escaping (_ node: String?, _ identities: [Identity], _ features: [String]) -> Void, onError: ((_ errorCondition: ErrorCondition?) -> Void)?) {
        getInfo(for: jid, node: requestedNode, callback: {(stanza: Stanza?) -> Void in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                guard let query = stanza!.findChild(name: "query", xmlns: DiscoveryModule.INFO_XMLNS) else {
                    onInfoReceived(requestedNode, [], []);
                    return;
                }
                let identities = query.mapChildren(transform: { e -> Identity in
                    return Identity(category: e.getAttribute("category")!, type: e.getAttribute("type")!, name: e.getAttribute("name"));
                    }, filter: { (e:Element) -> Bool in
                       return e.name == "identity" && e.getAttribute("category") != nil && e.getAttribute("type") != nil
                });
                let features = query.mapChildren(transform: { e -> String in
                    return e.getAttribute("var")!;
                    }, filter: { (e:Element) -> Bool in
                        return e.name == "feature" && e.getAttribute("var") != nil;
                })
                onInfoReceived(query.getAttribute("node") ?? requestedNode, identities, features);
            default:
                let errorCondition = stanza?.errorCondition;
                onError?(errorCondition);
            }
        })
    }
    
    /**
     Method retieves items available at particular XMPP recipient and it's node
     - parameter for: recipient to query
     - parameter node: node to query for items
     - parameter callback: called on result or failure
     */
    open func getItems(for jid:JID, node:String? = nil, callback: @escaping (Stanza?) -> Void) {
        let iq = Iq();
        iq.to  = jid;
        iq.type = StanzaType.get;
        let query = Element(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS);
        if node != nil {
            query.setAttribute("node", value: node);
        }
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }


    /**
     Method retieves items available at particular XMPP recipient and it's node
     - parameter for: recipient to query
     - parameter node: node to query for items
     - parameter onItemsReceived: called where response with result is received
     - parameter onError: called when received error or request timed out
     */
    open func getItems(for jid: JID, node requestedNode: String? = nil, onItemsReceived: @escaping (_ node:String?, _ items:[Item]) -> Void, onError: @escaping (_ errorCondition:ErrorCondition?) -> Void) {
        getItems(for: jid, node: requestedNode, callback: {(stanza:Stanza?) -> Void in
            let type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                guard let query = stanza!.findChild(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS) else {
                    onItemsReceived(requestedNode, []);
                    return;
                }
                let items = query.mapChildren(transform: { i -> Item in
                        return Item(jid: JID(i.getAttribute("jid")!), node: i.getAttribute("node"), name: i.getAttribute("name"));
                    }, filter: { (e) -> Bool in
                        return e.name == "item" && e.getAttribute("jid") != nil;
                })
                onItemsReceived(query.getAttribute("node") ?? requestedNode, items);
            default:
                let errorCondition = stanza?.errorCondition;
                onError(errorCondition);
            }
        });
    }
    
    /**
     Set custom callback for execution when remote entity will query for
     items or info of local node
     - parameter node: node name for which to execute
     - parameter entry: object with data
     */
    open func setNodeCallback(_ node_: String?, entry: NodeDetailsEntry?) {
        let node = node_ ?? "";
        if entry == nil {
            callbacks.removeValue(forKey: node);
        } else {
            callbacks[node] = entry;
        }
    }
    
    /**
     Processes stanzas with type equal `get`
     */
    open func processGet(stanza:Stanza) throws {
        let query = stanza.findChild(name: "query")!;
        let node = query.getAttribute("node");
        if let xmlns = query.xmlns {
            if let callback = callbacks[node ?? ""] {
                switch xmlns {
                case DiscoveryModule.INFO_XMLNS:
                    processGetInfo(stanza, node, callback);
                case DiscoveryModule.ITEMS_XMLNS:
                    processGetItems(stanza, node, callback);
                default:
                    throw ErrorCondition.bad_request;
                }
            }
        } else {
            throw ErrorCondition.bad_request;
        }
    }

    /**
     Processes stanzas with type equal `set`
     */
    open func processSet(stanza:Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
    
    func processGetInfo(_ stanza: Stanza, _ node: String?, _ nodeDetailsEntry: NodeDetailsEntry) {
        let result = stanza.makeResult(type: StanzaType.result);
        
        let queryResult = Element(name: "query", xmlns: DiscoveryModule.INFO_XMLNS);
        if node != nil {
            queryResult.setAttribute("node", value: node);
        }
        result.addChild(queryResult);
        
        if let identity = nodeDetailsEntry.identity(context.sessionObject, stanza, node) {
            let identityElement = Element(name: "identity");
            identityElement.setAttribute("category", value: identity.category);
            identityElement.setAttribute("type", value: identity.type);
            identityElement.setAttribute("name", value: identity.name);
            queryResult.addChild(identityElement);
        }
        
        if let features = nodeDetailsEntry.features(context.sessionObject, stanza, node) {
            for feature in features {
                let f = Element(name: "feature", attributes: [ "var" : feature ]);
                queryResult.addChild(f);
            }
        }
        
        context.writer?.write(result);
    }
    
    func processGetItems(_ stanza:Stanza, _ node:String?, _ nodeDetailsEntry:NodeDetailsEntry) {
        let result = stanza.makeResult(type: StanzaType.result);
        
        let queryResult = Element(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS);
        if node != nil {
            queryResult.setAttribute("node", value: node);
        }
        result.addChild(queryResult);
        
        if let items = nodeDetailsEntry.items(context.sessionObject, stanza, node) {
            for item in items {
                let e = Element(name: "item");
                e.setAttribute("jid", value: item.jid.description);
                e.setAttribute("node", value: item.node);
                e.setAttribute("name", value: item.name);
                queryResult.addChild(e);
            }
        }

        context.writer?.write(result);
    }
 
    /**
     Container class which holds informations to return on service 
     discovery for particular node
     */
    open class NodeDetailsEntry {
        public let identity: (_ sessionObject: SessionObject, _ stanza: Stanza, _ node: String?) -> Identity?
        public let features: (_ sessionObject: SessionObject, _ stanza: Stanza, _ node: String?) -> [String]?
        public let items: (_ sessionObject: SessionObject, _ stanza: Stanza, _ node: String?) -> [Item]?
        
        public init(identity: @escaping (_ sessionObject: SessionObject, _ stanza: Stanza, _ node: String?) -> Identity?, features: @escaping (_ sessionObject: SessionObject, _ stanza: Stanza, _ node: String?) -> [String]?, items: @escaping (_ sessionObject: SessionObject, _ stanza: Stanza, _ node: String?) -> [Item]?) {
            self.identity = identity;
            self.features = features;
            self.items = items;
        }
    }
    
    open class Identity: CustomStringConvertible {
        
        public let category: String;
        public let type: String;
        public let name: String?;
        
        public init(category: String, type: String, name: String? = nil) {
            self.category = category;
            self.type = type;
            self.name = name;
        }
        
        open var description: String {
            get {
                return "Identity(category=\(category), type=\(type), name=\(String(describing: name)))";
            }
        }
    }
    
    open class Item: CustomStringConvertible {
        
        public let jid:JID;
        public let node:String?;
        public let name:String?;
        
        public init(jid: JID, node: String? = nil, name: String? = nil) {
            self.jid = jid;
            self.node = node;
            self.name = name;
        }
        
        open var description: String {
            get {
                return "Item(jid=\(jid), node=\(String(describing: node)), name=\(String(describing: name)))";
            }
        }
    }
    
    /// Event fired when server features are retrieved
    open class ServerFeaturesReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ServerFeaturesReceivedEvent();
        
        public let type = "ServerFeaturesReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Array of available server features
        public let features: [String]!;
        public let identities: [Identity]!;
        
        init() {
            self.sessionObject = nil;
            self.features = nil;
            self.identities = nil;
        }
        
        public init(sessionObject: SessionObject, features: [String], identities: [Identity]) {
            self.sessionObject = sessionObject;
            self.features = features;
            self.identities = identities;
        }
    }

    /// Event fired when account features are retrieved
    open class AccountFeaturesReceivedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AccountFeaturesReceivedEvent();
        
        public let type = "AccountFeaturesReceivedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject: SessionObject!;
        /// Array of available server features
        public let features: [String]!;
        
        init() {
            self.sessionObject = nil;
            self.features = nil;
        }
        
        public init(sessionObject: SessionObject, features: [String]) {
            self.sessionObject = sessionObject;
            self.features = features;
        }
    }

}
