//
// CapabilitiesModule.swift
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
 Module implements support for [XEP-0115: Entity Capabilities].
 
 Requires `DiscoveryModule` to work properly.
 
 [XEP-0115: Entity Capabilities]:http://xmpp.org/extensions/xep-0115.html
 */
open class CapabilitiesModule: XmppModule, ContextAware, Initializable, EventHandler {
    
    /// Key used to cache verification string in `SessionObject`
    public static let VERIFICATION_STRING_KEY = "XEP115VerificationString";
    
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "caps";
    
    public let id = ID;
    public let criteria = Criteria.empty();
    public let features = ["http://jabber.org/protocol/caps"];
    
    open var context: Context! {
        willSet {
            guard context != nil else {
                return;
            }
            context.eventBus.unregister(handler: self, for: PresenceModule.BeforePresenceSendEvent.TYPE, PresenceModule.ContactPresenceChanged.TYPE);
        }
        
        didSet {
            guard context != nil else {
                return;
            }
            context.eventBus.register(handler: self, for: PresenceModule.BeforePresenceSendEvent.TYPE, PresenceModule.ContactPresenceChanged.TYPE);
        }
    }
    
    /// Keeps instance of `CapabilitiesCache` responsible for caching discovery results
    open var cache: CapabilitiesCache?;
    
    /// Node used in CAPS advertisement
    open var nodeName = "http://tigase.org/TigaseSwift" + "X";
    
    public init() {
        
    }
    
    /// Method do noting
    open func process(stanza: Stanza) throws {
        throw ErrorCondition.bad_request;
    }
    
    open func initialize() {
        if cache == nil {
            cache = DefaultCapabilitiesCache();
        }
    }
    
    open func handle(event: Event) {
        switch event {
        case let e as PresenceModule.BeforePresenceSendEvent:
            onBeforePresenceSend(event: e);
        case let e as PresenceModule.ContactPresenceChanged:
            onReceivedPresence(event: e);
        default:
            break;
        }
    }
    
    /**
     Method called before presence is sent by `PresenceModule.BeforePresenceSendEvent`
     This method is responsible for calculation of verification string if needed
     and injecting CAPS element to presence before it is send.
     
     - parameter event: event fired before `Presence` is send
     */
    func onBeforePresenceSend(event e: PresenceModule.BeforePresenceSendEvent) {
        guard let ver: String = context.sessionObject.getProperty(CapabilitiesModule.VERIFICATION_STRING_KEY) ?? calculateVerificationString() else {
            return;
        }
        
        let c = Element(name: "c", xmlns: "http://jabber.org/protocol/caps");
        c.setAttribute("hash", value: "sha-1");
        c.setAttribute("node", value: nodeName);
        c.setAttribute("ver", value: ver);
    
        e.presence.addChild(c);
    }
 
    /**
     Method called by event when `Presence` is received. It looks for CAPS payload
     and if unknown verification string is found it executes discovery to add it
     to cache.
     
     - parameter event: event fired when `Presence` is received
     */
    func onReceivedPresence(event e: PresenceModule.ContactPresenceChanged) {
        guard cache != nil && e.presence != nil, let from = e.presence.from else {
            return;
        }
        
        guard let nodeName = e.presence.capsNode else {
            return;
        }
        
        cache!.isCached(node: nodeName) { cached in
            guard let discoveryModule: DiscoveryModule = self.context.modulesManager.getModule(DiscoveryModule.ID) else {
                return;
            }
            discoveryModule.getInfo(for: from, node: nodeName, onInfoReceived: { (node, identities, features) in
                let identity = identities.first;
                self.cache?.store(node: node!, identity: identity, features: features);
            }, onError: nil);
        }
    }
    
    /**
     Method calculates verification string
     - returns: calculated verification string
     */
    func calculateVerificationString() -> String? {
        let category = context.sessionObject.getProperty(DiscoveryModule.IDENTITY_CATEGORY_KEY, defValue: "client");
        let type = context.sessionObject.getProperty(DiscoveryModule.IDENTITY_TYPE_KEY, defValue: "pc");
        let name = context.sessionObject.getProperty(SoftwareVersionModule.NAME_KEY, defValue: SoftwareVersionModule.DEFAULT_NAME_VAL);
        let version = context.sessionObject.getProperty(SoftwareVersionModule.VERSION_KEY, defValue: "0.0.0");
        
        let identity = "\(category)/\(type)/\(name) \(version)";
        
        let ver = generateVerificationString([identity], features: Array(context.modulesManager.availableFeatures));
        
        let oldVer: String? = context.sessionObject.getProperty(CapabilitiesModule.VERIFICATION_STRING_KEY);
        let discoveryModule: DiscoveryModule? = context.modulesManager.getModule(DiscoveryModule.ID);
        if oldVer != nil && ver != oldVer {
            discoveryModule?.setNodeCallback(nodeName + "#" + oldVer!, entry: nil);
        }
        if ver != nil {
            discoveryModule?.setNodeCallback(nodeName + "#" + ver!, entry: DiscoveryModule.NodeDetailsEntry(
                identity: { (sessionObject: SessionObject, stanza: Stanza, node: String?) -> DiscoveryModule.Identity? in
                    return DiscoveryModule.Identity(category: sessionObject.getProperty(DiscoveryModule.IDENTITY_CATEGORY_KEY, defValue: "client"),
                        type: sessionObject.getProperty(DiscoveryModule.IDENTITY_TYPE_KEY, defValue: "pc"),
                        name: sessionObject.getProperty(SoftwareVersionModule.NAME_KEY, defValue: SoftwareVersionModule.DEFAULT_NAME_VAL)
                    );
                },
                features: { (sessionObject: SessionObject, stanza: Stanza, node: String?) -> [String]? in
                    return Array(self.context.modulesManager.availableFeatures);
                },
                items: { (sessionObject: SessionObject, stanza: Stanza, node: String?) -> [DiscoveryModule.Item]? in
                    return nil;
            }));
        }
        
        context.sessionObject.setProperty(CapabilitiesModule.VERIFICATION_STRING_KEY, value: ver);
        
        return ver;
    }

    /**
     Method generates verification string from passed parameters.
     - parameter identities: XMPP client identities
     - parameter features: available feature for client
     - returns: verification string
     */
    func generateVerificationString(_ identities: [String], features availableFeatures: [String]) -> String? {
        let features = availableFeatures.sorted();
        var string: String = "";
        
        for identity in identities {
            string += identity + "<";
        }
        
        for feature in features {
            string += feature + "<";
        }
        
        return Digest.sha1.digest(toBase64: string.data(using: String.Encoding.utf8));
    }
}

/**
 Protocol which is required to be implemented by class responsible for caching
 information about features and identities.
 */
public protocol CapabilitiesCache {
    /**
     Retreives array of features available for particular node from cache
     - parameter for: node for which we want to check supported features
     - returns: array of supported features or `nil` if there is not entry in
     cache for this node
     */
    func getFeatures(for node: String) -> [String]?;
    
    /**
     Retrieve identity of remote client which adverties this node
     - parameter for: node to look for identity
     - returns: XMPP client idenitity or `nil` if no available in cache
     */
    func getIdentity(for node: String) -> DiscoveryModule.Identity?;
    
    /**
     Retrieves array of nodes which supports feature
     - parameter withFeature: feature which should be supported
     - returns: array of nodes supporting this feature known in cache
     */
    func getNodes(withFeature feature: String) -> [String];
    
    /**
     Check if information for node are in cache
     - parameter node: node to check
     - returns: true if data is available in cache
     */
    func isCached(node: String, handler: @escaping (Bool)->Void);
    
    /**
     Check if feature is supported for node in cache.
     - parameter for: node to check
     - parameter feature: feature to check support
     - returns: true if feature is supported by this node
     */
    func isSupported(for node: String, feature: String) -> Bool;
    
    /**
     Store data in cache
     - parameter node: node for which we store data
     - parameter identitity: XMPP client identity
     - parameter features: array of feature supported by client
     */
    func store(node: String, identity: DiscoveryModule.Identity?, features: [String]);
    
}

extension Presence {
    open var capsNode: String? {
        get {
            guard let c = element.findChild(name: "c", xmlns: "http://jabber.org/protocol/caps") else {
                return nil;
            }
            guard let node = c.getAttribute("node"), let ver = c.getAttribute("ver") else {
                return nil;
            }
            return node + "#" + ver;
        }
    }
}
