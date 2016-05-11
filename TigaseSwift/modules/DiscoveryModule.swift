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

public class DiscoveryModule: Logger, AbstractIQModule, ContextAware {

    public static let IDENTITY_CATEGORY_KEY = "discoveryIdentityCategory";
    public static let IDENTITY_TYPE_KEY = "discoveryIdentityType";
    public static let ITEMS_XMLNS = "http://jabber.org/protocol/disco#items";
    public static let INFO_XMLNS = "http://jabber.org/protocol/disco#info";
    
    public static let ID = "discovery";
    
    public let id = ID;
    
    public var context:Context!;
    
    public let criteria = Criteria.name("iq").add(
        Criteria.or(
            Criteria.name("query", xmlns: DiscoveryModule.ITEMS_XMLNS),
            Criteria.name("query", xmlns: DiscoveryModule.INFO_XMLNS)
        )
    );
    
    public let features = [ DiscoveryModule.ITEMS_XMLNS, DiscoveryModule.INFO_XMLNS ];
    
    private var callbacks = [String:NodeDetailsEntry]();
    
    public override init() {
        super.init()
        setNodeCallback(nil, entry: NodeDetailsEntry(
            identity: { (sessionObject: SessionObject, stanza: Stanza, node: String) -> Identity? in
                return Identity(category: sessionObject.getProperty(DiscoveryModule.IDENTITY_CATEGORY_KEY, defValue: "client"),
                    type: sessionObject.getProperty(DiscoveryModule.IDENTITY_TYPE_KEY, defValue: "pc"),
                    name: sessionObject.getProperty(SoftwareVersionModule.NAME_KEY, defValue: SoftwareVersionModule.DEFAULT_NAME_VAL)
                );
            },
            features: { (sessionObject: SessionObject, stanza: Stanza, node: String) -> [String]? in
                return Array(self.context.modulesManager.availableFeatures);
            },
            items: { (sessionObject: SessionObject, stanza: Stanza, node: String) -> [Item]? in
                return nil;
            }
        ));
    }
    
    public func discoverServerFeatures(onInfoReceived:((node: String?, identities: [Identity], features: [String]) -> Void)?, onError: ((errorCondition: ErrorCondition?) -> Void)?) {
        if let jid = ResourceBinderModule.getBindedJid(context.sessionObject) {
            getInfo(JID(jid.domain), onInfoReceived: {(node :String?, identities: [Identity], features: [String]) -> Void in
                self.context.eventBus.fire(ServerFeaturesReceivedEvent(sessionObject: self.context.sessionObject, features: features));
                onInfoReceived?(node: node, identities: identities, features: features);
                }, onError: onError);
        }
    }
    
    public func getInfo(jid: JID, node: String?, callback: (Stanza?) -> Void) {
        var iq = Iq();
        iq.to  = jid;
        iq.type = StanzaType.get;
        var query = Element(name: "query", xmlns: DiscoveryModule.INFO_XMLNS);
        if node != nil {
            query.setAttribute("node", value: node);
        }
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }
    
    public func getInfo(jid:JID, node:String? = nil, onInfoReceived:(node: String?, identities: [Identity], features: [String]) -> Void, onError: ((errorCondition: ErrorCondition?) -> Void)?) {
        getInfo(jid, node:node, callback: {(stanza: Stanza?) -> Void in
            var type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                var query = stanza!.findChild("query", xmlns: DiscoveryModule.INFO_XMLNS);
                let identities = query!.mapChildren({ e -> Identity in
                    return Identity(category: e.getAttribute("category")!, type: e.getAttribute("type")!, name: e.getAttribute("name"));
                    }, filter: { (e:Element) -> Bool in
                       return e.name == "identity"
                });
                let features = query!.mapChildren({ e -> String in
                    return e.getAttribute("var")!;
                    }, filter: { (e:Element) -> Bool in
                        return e.name == "feature" && e.getAttribute("var") != nil;
                })
                onInfoReceived(node: query?.getAttribute("node"), identities: identities, features: features);
            default:
                var errorCondition = stanza?.errorCondition;
                onError?(errorCondition: errorCondition);
            }
        })
    }
    
    public func getItems(jid:JID, node:String? = nil, callback: (Stanza?) -> Void) {
        var iq = Iq();
        iq.to  = jid;
        iq.type = StanzaType.get;
        var query = Element(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS);
        if node != nil {
            query.setAttribute("node", value: node);
        }
        iq.addChild(query);
        
        context.writer?.write(iq, callback: callback);
    }


    public func getItems(jid:JID, node:String? = nil, onItemsReceived:(node:String?, items:[Item]) -> Void, onError:(errorCondition:ErrorCondition?) -> Void) {
        getItems(jid, node: node, callback: {(stanza:Stanza?) -> Void in
            var type = stanza?.type ?? StanzaType.error;
            switch type {
            case .result:
                var query = stanza!.findChild("query", xmlns: DiscoveryModule.ITEMS_XMLNS);
                var items = query!.mapChildren({ i -> Item in
                        return Item(jid: JID(i.getAttribute("jid")!), node: i.getAttribute("node"), name: i.getAttribute("name"));
                    }, filter: { (e) -> Bool in
                        return e.name == "item";
                })
                onItemsReceived(node: query?.getAttribute("node"), items: items);
            default:
                var errorCondition = stanza?.errorCondition;
                onError(errorCondition: errorCondition);
            }
        });
    }
    public func setNodeCallback(node_: String?, entry: NodeDetailsEntry?) {
        var node = node_ ?? "";
        if entry == nil {
            callbacks.removeValueForKey(node);
        } else {
            callbacks[node] = entry;
        }
    }
    
    public func processGet(stanza:Stanza) throws {
        let query = stanza.findChild("query")!;
        let node = query.getAttribute("node") ?? "";
        if let xmlns = query.xmlns {
            if let callback = callbacks[node] {
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
    public func processSet(stanza:Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
    
    func processGetInfo(stanza:Stanza, _ node:String, _ nodeDetailsEntry:NodeDetailsEntry) {
        var result = stanza.makeResult(StanzaType.result);
        
        var queryResult = Element(name: "query", xmlns: DiscoveryModule.INFO_XMLNS);
        result.addChild(queryResult);
        
        if let identity = nodeDetailsEntry.identity(sessionObject: context.sessionObject, stanza: stanza, node: node) {
            var identityElement = Element(name: "identity");
            identityElement.setAttribute("category", value: identity.category);
            identityElement.setAttribute("type", value: identity.type);
            identityElement.setAttribute("name", value: identity.name);
            queryResult.addChild(identityElement);
        }
        
        if let features = nodeDetailsEntry.features(sessionObject: context.sessionObject, stanza: stanza, node: node) {
            for feature in features {
                var f = Element(name: "feature", attributes: [ "var" : feature ]);
                queryResult.addChild(f);
            }
        }
        
        context.writer?.write(result);
    }
    
    func processGetItems(stanza:Stanza, _ node:String, _ nodeDetailsEntry:NodeDetailsEntry) {
        var result = stanza.makeResult(StanzaType.result);
        
        var queryResult = Element(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS);
        result.addChild(queryResult);
        
        if let items = nodeDetailsEntry.items(sessionObject: context.sessionObject, stanza: stanza, node: node) {
            for item in items {
                var e = Element(name: "item");
                e.setAttribute("jid", value: item.jid.description);
                e.setAttribute("node", value: item.node);
                e.setAttribute("name", value: item.name);
                queryResult.addChild(e);
            }
        }

        context.writer?.write(result);
    }
 
    public class NodeDetailsEntry {
        public let identity: (sessionObject: SessionObject, stanza: Stanza, node: String) -> Identity?
        public let features: (sessionObject: SessionObject, stanza: Stanza, node: String) -> [String]?
        public let items: (sessionObject: SessionObject, stanza: Stanza, node: String) -> [Item]?
        
        public init(identity: (sessionObject: SessionObject, stanza: Stanza, node: String) -> Identity?, features: (sessionObject: SessionObject, stanza: Stanza, node: String) -> [String]?, items: (sessionObject: SessionObject, stanza: Stanza, node: String) -> [Item]?) {
            self.identity = identity;
            self.features = features;
            self.items = items;
        }
    }
    
    public class Identity: CustomStringConvertible {
        
        public let category: String;
        public let type: String;
        public let name: String?;
        
        public init(category: String, type: String, name: String? = nil) {
            self.category = category;
            self.type = type;
            self.name = name;
        }
        
        public var description: String {
            get {
                return "Identity(category=\(category), type=\(type), name=\(name))";
            }
        }
    }
    
    public class Item: CustomStringConvertible {
        
        public let jid:JID;
        public let node:String?;
        public let name:String?;
        
        public init(jid: JID, node: String? = nil, name: String? = nil) {
            self.jid = jid;
            self.node = node;
            self.name = name;
        }
        
        public var description: String {
            get {
                return "Item(jid=\(jid), node=\(node), name=\(name))";
            }
        }
    }
    
    public class ServerFeaturesReceivedEvent: Event {
        
        public static let TYPE = ServerFeaturesReceivedEvent();
        
        public let type = "ServerFeaturesReceivedEvent";
        
        public let sessionObject: SessionObject!;
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