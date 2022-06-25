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
        if let jid = context?.boundJid {
            getInfo(for: jid.withoutResource, completionHandler: { result in
                switch result {
                case .success(let info):
                    self.accountDiscoResult = info;
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
            query.attribute("node", newValue: node);
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
                guard let query = stanza.firstChild(name: "query", xmlns: DiscoveryModule.INFO_XMLNS) else {
                    return .empty();
                }
                let identities = query.compactMapChildren(Identity.init(_:));
                let features = query.filterChildren(name: "feature").compactMap({ $0.attribute("var") });
                let form = DataForm(element: query.firstChild(name: "x", xmlns: "jabber:x:data"));
                return DiscoveryInfoResult(identities: identities, features: features, form: form);
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
            query.attribute("node", newValue: node);
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
                guard let query = stanza.firstChild(name: "query", xmlns: DiscoveryModule.ITEMS_XMLNS) else {
                    return DiscoveryItemsResult(node: requestedNode, items: []);
                }
                let items = query.compactMapChildren(Item.init(_:));
                return DiscoveryItemsResult(node: query.attribute("node") ?? requestedNode, items: items);
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
        let query = stanza.firstChild(name: "query")!;
        let node = query.attribute("node");
        if let xmlns = query.xmlns {
            if let callback = callbacks[node ?? ""] {
                switch xmlns {
                case DiscoveryModule.INFO_XMLNS:
                    processGetInfo(stanza, node, callback);
                case DiscoveryModule.ITEMS_XMLNS:
                    processGetItems(stanza, node, callback);
                default:
                    throw XMPPError.bad_request(nil);
                }
            }
        } else {
            throw XMPPError.bad_request(nil);
        }
    }

    /**
     Processes stanzas with type equal `set`
     */
    open func processSet(stanza:Stanza) throws {
        throw XMPPError.not_allowed(nil);
    }
    
    private func processGetInfo(_ stanza: Stanza, _ node: String?, _ nodeDetailsEntry: NodeDetailsEntry) {
        let result = stanza.makeResult(type: StanzaType.result);
        
        let queryResult = Element(name: "query", xmlns: DiscoveryModule.INFO_XMLNS);
        if node != nil {
            queryResult.attribute("node", newValue: node);
        }
        result.addChild(queryResult);
        
        if let context = context, let identity = nodeDetailsEntry.identity(context, stanza, node) {
            let identityElement = Element(name: "identity");
            identityElement.attribute("category", newValue: identity.category);
            identityElement.attribute("type", newValue: identity.type);
            identityElement.attribute("name", newValue: identity.name);
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
            queryResult.attribute("node", newValue: node);
        }
        result.addChild(queryResult);
        
        if let context = context, let items = nodeDetailsEntry.items(context, stanza, node) {
            for item in items {
                let e = Element(name: "item");
                e.attribute("jid", newValue: item.jid.description);
                e.attribute("node", newValue: item.node);
                e.attribute("name", newValue: item.name);
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
    
    public struct Identity: CustomStringConvertible {
        
        public let category: String;
        public let type: String;
        public let name: String?;
        
        public init?(_ el: Element) {
            guard el.name == "identity" else {
                return nil;
            }
            guard let category = el.attribute("category"), let type = el.attribute("type") else {
                return nil;
            }
            self.category = category;
            self.type = type;
            name = el.attribute("name");
        }
        
        public init(category: String, type: String, name: String? = nil) {
            self.category = category;
            self.type = type;
            self.name = name;
        }
        
        public var description: String {
            get {
                return "Identity(category=\(category), type=\(type), name=\(String(describing: name)))";
            }
        }
    }
    
    public struct Item: CustomStringConvertible {
        
        public let jid:JID;
        public let node:String?;
        public let name:String?;
        
        public init?(_ el: Element) {
            guard el.name == "item" else {
                return nil;
            }
            guard let jid = JID(el.attribute("jid")) else {
                return nil;
            }
            self.jid = jid;
            self.node = el.attribute("node");
            self.name = el.attribute("name");
        }
        
        public init(jid: JID, node: String? = nil, name: String? = nil) {
            self.jid = jid;
            self.node = node;
            self.name = name;
        }
        
        public var description: String {
            get {
                return "Item(jid=\(jid), node=\(String(describing: node)), name=\(String(describing: name)))";
            }
        }
    }

    public struct DiscoveryInfoResult {
        public let identities: [Identity];
        public let features: [String];
        public let form: DataForm?;
        
        public init(identities: [Identity], features: [String], form: DataForm?) {
            self.identities = identities;
            self.features = features;
            self.form = form;
        }
        
        public static func empty() -> DiscoveryInfoResult {
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

// async-await support
extension DiscoveryModule {
    
    open func serverFeatures() async throws -> DiscoveryInfoResult {
        guard let boundJid = context?.boundJid, let serverJid = JID(boundJid.domain) else {
            throw XMPPError.unexpected_request("Resournce not bound yet!")
        }
        return try await info(for: serverJid);
    }
    
    open func accountFeatures() async throws -> DiscoveryInfoResult {
        guard let accountJid = context?.boundJid?.withoutResource else {
            throw XMPPError.unexpected_request("Resournce not bound yet!")
        }
        return try await info(for: accountJid);
    }
    
    open func info(for jid: JID, node: String? = nil) async throws -> DiscoveryInfoResult {
        return try await withUnsafeThrowingContinuation { continuation in
            getInfo(for: jid, node: node, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func items(for jid: JID, node requestedNode: String? = nil) async throws -> DiscoveryItemsResult {
        return try await withUnsafeThrowingContinuation { continuation in
            getItems(for: jid, node: requestedNode, completionHandler: { result in
                continuation.resume(with: result);
            })
        }
    }
    
    open func serverComponents() async throws -> DiscoveryItemsResult {
        guard let boundJid = context?.boundJid, let serverJid = JID(boundJid.domain) else {
            throw XMPPError.unexpected_request("Resournce not bound yet!")
        }
        return try await items(for: serverJid);
    }
}
