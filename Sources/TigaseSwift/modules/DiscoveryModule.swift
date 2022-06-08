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

extension XmppModuleIdentifier {
    public static var disco: XmppModuleIdentifier<DiscoveryModule> {
        return DiscoveryModule.IDENTIFIER;
    }
}

/**
 Module responsible for [XEP-0030: Service Discovery] feature.
 
 [XEP-0030: Service Discovery]: http://xmpp.org/extensions/xep-0030.html
 */
open class DiscoveryModule: XmppModuleBase, AbstractIQModule, Resetable {

    /// Namespace used by service discovery
    public static let ITEMS_XMLNS = "http://jabber.org/protocol/disco#items";
    /// Namespace used by service discovery
    public static let INFO_XMLNS = "http://jabber.org/protocol/disco#info";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "discovery";
    public static let IDENTIFIER = XmppModuleIdentifier<DiscoveryModule>();
        
    public let criteria = Criteria.name("iq").add(
        Criteria.or(
            Criteria.name("query", xmlns: DiscoveryModule.ITEMS_XMLNS),
            Criteria.name("query", xmlns: DiscoveryModule.INFO_XMLNS)
        )
    );
    
    public let features = [ DiscoveryModule.ITEMS_XMLNS, DiscoveryModule.INFO_XMLNS ];
    
    fileprivate var callbacks = [String:NodeDetailsEntry]();
    
    public let identity: Identity;
    
    @Published
    public private(set) var serverDiscoResult: DiscoveryInfoResult = .empty();
    @Published
    public private(set) var accountDiscoResult: DiscoveryInfoResult = .empty();
    
    public init(identity: Identity = Identity(category: "client", type: "pc", name: SoftwareVersionModule.DEFAULT_NAME_VAL)) {
        self.identity = identity;
        super.init();
        setNodeCallback(nil, entry: NodeDetailsEntry(
            identity: { [weak self] (context: Context, stanza: Stanza, node: String?) -> Identity? in
                return self?.identity;
            },
            features: { (context: Context, stanza: Stanza, node: String?) -> [String]? in
                return Array(context.modulesManager.availableFeatures);
            },
            items: { (context: Context, stanza: Stanza, node: String?) -> [Item]? in
                return nil;
            }
        ));
    }
    
    /**
     Method sends query to server to discover server features
     - parameter onInfoReceived: called when info will be available
     - parameter onError: called when received error or request timed out
     */
    open func discoverServerFeatures(completionHandler: ((Result<DiscoveryInfoResult,XMPPError>)->Void)?) {
        if let jid = context?.boundJid {
            getInfo(for: JID(jid.domain), completionHandler: { result in
                switch result {
                case .success(let info):
                    self.serverDiscoResult = info;
                    if let context = self.context {
                        self.fire(ServerFeaturesReceivedEvent(context: context, features: info.features, identities: info.identities));
                    }
                default:
                    break;
                }
                completionHandler?(result);
            });
        }
    }
    
    /**
     Method sends query to the account bare jid to discover server features handled on behalf of the user
     - parameter onInfoReceived: called when info will be available
     - parameter onError: called when received error or request timed out
     */
    open func discoverAccountFeatures(completionHandler:((Result<DiscoveryInfoResult,XMPPError>) -> Void)?) {
        if let jid = context?.boundJid, let context = context {
            getInfo(for: jid.withoutResource, completionHandler: { result in
                switch result {
                case .success(let info):
                    self.accountDiscoResult = info;
                    self.fire(AccountFeaturesReceivedEvent(context: context, features: info.features));
                default:
                    break;
                }
                completionHandler?(result);
            });
        }
    }
    
    /**
     Method retieves informations about particular XMPP recipient and it's node
     - parameter for: recipient to query
     - parameter node: node to query for informations
     - parameter callback: called on result or failure
     */
    open func getInfo<Failure: Error>(for jid: JID, node: String?, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>) -> Void) {
        let iq = Iq();
        iq.to  = jid;
        iq.type = StanzaType.get;
        let query = Element(name: "query", xmlns: DiscoveryModule.INFO_XMLNS);
        if node != nil {
            query.setAttribute("node", value: node);
        }
        iq.addChild(query);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    /**
     Method retieves informations about particular XMPP recipient and it's node
     - parameter for: recipient to query
     - parameter node: node to query for informations
     - parameter completionHandler: called where result is available
     */
    open func getInfo(for jid:JID, node requestedNode:String? = nil, completionHandler: @escaping (Result<DiscoveryInfoResult,XMPPError>) -> Void) {
        getInfo(for: jid, node: requestedNode, errorDecoder: XMPPError.from(stanza: ), completionHandler: { result in
            completionHandler(result.map { stanza in
                guard let query = stanza.findChild(name: "query", xmlns: DiscoveryModule.INFO_XMLNS) else {
                    return .empty();
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
                let form = JabberDataElement(from: query.findChild(name: "x", xmlns: "jabber:x:data"));
                return DiscoveryInfoResult(identities: identities, features: features, form: form);
            });
        })
    }
    
    open func getInfo(for jid:JID, node requestedNode:String? = nil, resultHandler: @escaping (Result<DiscoveryInfoResult2,XMPPError>) -> Void) {
        getInfo(for: jid, node: requestedNode, errorDecoder: XMPPError.from(stanza: ), completionHandler: { result in
            resultHandler(result.map { stanza in
                guard let query = stanza.findChild(name: "query", xmlns: DiscoveryModule.INFO_XMLNS) else {
                    return .empty();
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
                let form = DataForm(element: query.findChild(name: "x", xmlns: "jabber:x:data"));
                return DiscoveryInfoResult2(identities: identities, features: features, form: form);
            });
        })
    }

    /**
     Method retieves items available at particular XMPP recipient and it's node
     - parameter for: recipient to query
     - parameter node: node to query for items
     - parameter callback: called on result or failure
     */
    open func getItems<Failure: Error>(for jid: JID, node: String? = nil, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: @escaping (Result<Iq,Failure>) -> Void) {
        let iq = Iq();
        iq.to  = jid;
        iq.type = StanzaType.get;
        let query = Element(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS);
        if node != nil {
            query.setAttribute("node", value: node);
        }
        iq.addChild(query);
        
        write(iq, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }

    /**
     Method retieves items available at particular XMPP recipient and it's node
     - parameter for: recipient to query
     - parameter node: node to query for items
     - parameter completionHandler: called where result is available
     */
    open func getItems(for jid: JID, node requestedNode: String? = nil, completionHandler: @escaping (Result<DiscoveryItemsResult,XMPPError>) -> Void) {
        getItems(for: jid, node: requestedNode, errorDecoder: XMPPError.from(stanza: ), completionHandler: { result in
            completionHandler(result.map({ stanza in
                guard let query = stanza.findChild(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS) else {
                    return DiscoveryItemsResult(node: requestedNode, items: []);
                }
                let items = query.mapChildren(transform: { i -> Item in
                        return Item(jid: JID(i.getAttribute("jid")!), node: i.getAttribute("node"), name: i.getAttribute("name"));
                    }, filter: { (e) -> Bool in
                        return e.name == "item" && e.getAttribute("jid") != nil;
                })
                return DiscoveryItemsResult(node: query.getAttribute("node") ?? requestedNode, items: items);
            }))
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
    
    private func processGetInfo(_ stanza: Stanza, _ node: String?, _ nodeDetailsEntry: NodeDetailsEntry) {
        let result = stanza.makeResult(type: StanzaType.result);
        
        let queryResult = Element(name: "query", xmlns: DiscoveryModule.INFO_XMLNS);
        if node != nil {
            queryResult.setAttribute("node", value: node);
        }
        result.addChild(queryResult);
        
        if let context = context, let identity = nodeDetailsEntry.identity(context, stanza, node) {
            let identityElement = Element(name: "identity");
            identityElement.setAttribute("category", value: identity.category);
            identityElement.setAttribute("type", value: identity.type);
            identityElement.setAttribute("name", value: identity.name);
            queryResult.addChild(identityElement);
        }
        
        if let context = context, let features = nodeDetailsEntry.features(context, stanza, node) {
            for feature in features {
                let f = Element(name: "feature", attributes: [ "var" : feature ]);
                queryResult.addChild(f);
            }
        }
        
        write(result);
    }
    
    private func processGetItems(_ stanza:Stanza, _ node:String?, _ nodeDetailsEntry:NodeDetailsEntry) {
        let result = stanza.makeResult(type: StanzaType.result);
        
        let queryResult = Element(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS);
        if node != nil {
            queryResult.setAttribute("node", value: node);
        }
        result.addChild(queryResult);
        
        if let context = context, let items = nodeDetailsEntry.items(context, stanza, node) {
            for item in items {
                let e = Element(name: "item");
                e.setAttribute("jid", value: item.jid.description);
                e.setAttribute("node", value: item.node);
                e.setAttribute("name", value: item.name);
                queryResult.addChild(e);
            }
        }

        write(result);
    }
 
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.session) {
            self.accountDiscoResult = .empty();
            self.serverDiscoResult = .empty();
        }
    }
    
    /**
     Container class which holds informations to return on service 
     discovery for particular node
     */
    open class NodeDetailsEntry {
        public let identity: (_ context: Context, _ stanza: Stanza, _ node: String?) -> Identity?
        public let features: (_ context: Context, _ stanza: Stanza, _ node: String?) -> [String]?
        public let items: (_ context: Context, _ stanza: Stanza, _ node: String?) -> [Item]?
        
        public init(identity: @escaping (_ context: Context, _ stanza: Stanza, _ node: String?) -> Identity?, features: @escaping (_ context: Context, _ stanza: Stanza, _ node: String?) -> [String]?, items: @escaping (_ context: Context, _ stanza: Stanza, _ node: String?) -> [Item]?) {
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
    @available(*, deprecated, message: "Use $serverDiscoResult publisher")
    open class ServerFeaturesReceivedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ServerFeaturesReceivedEvent();

        /// Array of available server features
        public let features: [String]!;
        public let identities: [Identity]!;

        init() {
            self.features = nil;
            self.identities = nil;
            super.init(type: "ServerFeaturesReceivedEvent");
        }

        public init(context: Context, features: [String], identities: [Identity]) {
            self.features = features;
            self.identities = identities;
            super.init(type: "ServerFeaturesReceivedEvent", context: context)
        }
    }

    /// Event fired when account features are retrieved
    @available(*, deprecated, message: "Use $accountDiscoResult publisher")
    open class AccountFeaturesReceivedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AccountFeaturesReceivedEvent();

        /// Array of available server features
        public let features: [String]!;

        init() {
            self.features = nil;
            super.init(type: "AccountFeaturesReceivedEvent")
        }

        public init(context: Context, features: [String]) {
            self.features = features;
            super.init(type: "AccountFeaturesReceivedEvent", context: context);
        }
    }

    public struct DiscoveryInfoResult {
        public let identities: [Identity];
        public let features: [String];
        public let form: JabberDataElement?;
        
        public init(identities: [Identity], features: [String], form: JabberDataElement?) {
            self.identities = identities;
            self.features = features;
            self.form = form;
        }
        
        public static func empty() -> DiscoveryInfoResult {
            return .init(identities: [], features: [], form: nil);
        }
    }
    
    public struct DiscoveryInfoResult2 {
        public let identities: [Identity];
        public let features: [String];
        public let form: DataForm?;
        
        public init(identities: [Identity], features: [String], form: DataForm?) {
            self.identities = identities;
            self.features = features;
            self.form = form;
        }
        
        public static func empty() -> DiscoveryInfoResult2 {
            return .init(identities: [], features: [], form: nil);
        }
    }
    
    public struct DiscoveryItemsResult {
        public let node: String?;
        public let items: [Item];
        
        public init(node: String?, items: [Item]) {
            self.node = node;
            self.items = items;
        }
    }
}
