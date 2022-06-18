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
import TigaseLogging

extension XmppModuleIdentifier {
    public static var caps: XmppModuleIdentifier<CapabilitiesModule> {
        return CapabilitiesModule.IDENTIFIER;
    }
}

/**
 Module implements support for [XEP-0115: Entity Capabilities].
 
 Requires `DiscoveryModule` to work properly.
 
 [XEP-0115: Entity Capabilities]:http://xmpp.org/extensions/xep-0115.html
 */
open class CapabilitiesModule: XmppModuleBase, XmppModule {
        
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "caps";
    public static let IDENTIFIER = XmppModuleIdentifier<CapabilitiesModule>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "CapabilitiesModule");
    
    public let criteria = Criteria.empty();
    public var features: [String] {
        return ["http://jabber.org/protocol/caps"] + additionalFeatures.map({ $0.rawValue });
    }
    
    open override weak var context: Context? {
        willSet {
            if let context = context {
                discoModule = nil;
                presenceModule = nil;
            }
        }
        
        didSet {
            if let context = context {
                discoModule = context.modulesManager.module(.disco);
                presenceModule = context.modulesManager.module(.presence);
                presenceModule.$presence.sink(receiveValue: { [weak self] presence in
                    self?.updateCaps(in: presence);
                }).store(in: self);
                presenceModule.presencePublisher.sink(receiveValue: { [weak self] presence in
                    self?.receivedPresence(presence);
                }).store(in: self);
            }
        }
    }
    
    /// Keeps instance of `CapabilitiesCache` responsible for caching discovery results
    public let cache: CapabilitiesCache;
    private var verificationString: String?;

    /// Node used in CAPS advertisement
    open var nodeName = "http://tigase.org/TigaseSwift" + "X";
    
    private var presenceModule: PresenceModule!;
    private var discoModule: DiscoveryModule!;
    private let dispatcher = QueueDispatcher(label: "capsInProgressSynchronizer");
    private var inProgress: [String] = [];
    
    public let additionalFeatures: [AdditionalFeatures];
    
    public init(cache: CapabilitiesCache = DefaultCapabilitiesCache(), additionalFeatures: [AdditionalFeatures] = []) {
        self.cache = cache;
        self.additionalFeatures = additionalFeatures;
    }
    
    /// Method do noting
    open func process(stanza: Stanza) throws {
        throw XMPPError.bad_request(nil);
    }
    
    open func updateCaps(in presence: Presence) {
        if let oldC = presence.findChild(name: "c", xmlns: "http://jabber.org/protocol/caps") {
            presence.removeChild(oldC);
        }

        logger.debug("updating presence CAPS...")
        
        guard let ver: String = self.verificationString ?? calculateVerificationString() else {
            return;
        }
            
        let c = Element(name: "c", xmlns: "http://jabber.org/protocol/caps");
        c.setAttribute("hash", value: "sha-1");
        c.setAttribute("node", value: nodeName);
        c.setAttribute("ver", value: ver);
    
        presence.addChild(c);
    }
 
    open func receivedPresence(_ change: PresenceModule.ContactPresenceChange) {
        let type = change.presence.type ?? .available;
        guard let from = change.presence.from, type == .available else {
            return;
        }
        
        guard let nodeName = change.presence.capsNode else {
            return;
        }
        
        logger.debug("updating CAPS for \(from)")
        
        dispatcher.async {
            guard !self.inProgress.contains(nodeName) else {
                return;
            }
            self.cache.isCached(node: nodeName) { cached in
                guard !cached else {
                    return;
                }
                self.dispatcher.async {
                    guard !self.inProgress.contains(nodeName) else {
                        return;
                    }
                    self.inProgress.append(nodeName);
                    self.logger.debug("\(self.context) - caps disco#info send for: \(nodeName, privacy: .public) to: \(from, privacy: .auto(mask: .hash))");
                    self.discoModule.getInfo(for: from, node: nodeName, completionHandler: { result in
                        self.dispatcher.async {
                            if let idx = self.inProgress.firstIndex(of: nodeName) {
                                self.inProgress.remove(at: idx);
                                self.logger.debug("\(self.context) - caps disco#info received from: \(from, privacy: .public) result: \(result, privacy: .public)");
                            }
                            switch result {
                            case .success(let info):
                                let identity = info.identities.first;
                                self.cache.store(node: nodeName, identity: identity, features: info.features);
                            default:
                                break;
                            }
                        }
                    });
                }
            }
        }
    }
    
    /**
     Method calculates verification string
     - returns: calculated verification string
     */
    func calculateVerificationString() -> String? {
        guard let context = self.context else {
            return nil;
        }
        let identity = "\(discoModule.identity.category)/\(discoModule.identity.type)//\(discoModule.identity.name ?? SoftwareVersionModule.DEFAULT_NAME_VAL)";
        
        let ver = generateVerificationString([identity], features: Array(context.modulesManager.availableFeatures));
        
        let oldVer: String? = verificationString;
        if oldVer != nil && ver != oldVer {
            discoModule.setNodeCallback(nodeName + "#" + oldVer!, entry: nil);
        }
        if ver != nil {
            let identity = discoModule.identity;
            discoModule.setNodeCallback(nodeName + "#" + ver!, entry: DiscoveryModule.NodeDetailsEntry(
                identity: { (context: Context, stanza: Stanza, node: String?) -> DiscoveryModule.Identity? in
                    return identity;
                },
                features: { (context: Context, stanza: Stanza, node: String?) -> [String]? in
                    return Array(context.modulesManager.availableFeatures);
                },
                items: { (context: Context, stanza: Stanza, node: String?) -> [DiscoveryModule.Item]? in
                    return nil;
            }));
        }
        
        self.verificationString = ver;
        
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
        
    public enum FeatureSupported {
        case all
        case some([JID])
        case none
    }
    
    public func isFeatureSupported(_ feature: String, by jid: BareJID) -> FeatureSupported {
        guard let context = self.context else {
            return .none;
        }
        
        let presences = presenceModule.store.presences(for: jid, context: context);
        guard !presences.isEmpty else {
            return .none;
        }
        
        let withSupport = presences.filter({ presence in
            if let capsNode = presence.capsNode, cache.isSupported(for: capsNode, feature: feature) {
                return true;
            }
            return false;
        }).compactMap({ $0.from });
        
        guard presences.count == withSupport.count else {
            return withSupport.isEmpty ? .none : .some(withSupport);
        }
        return .all;
    }
    
    public func isFeatureSupported(_ feature: String, by jid: JID) -> Bool {
        guard let context = self.context else {
            return false;
        }
        guard let capsNode = presenceModule.store.presence(for: jid, context: context)?.capsNode else {
            return false;
        }
        return cache.isSupported(for: capsNode, feature: feature);
    }
    
    public struct AdditionalFeatures: RawRepresentable {
        public let rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue;
        }
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
