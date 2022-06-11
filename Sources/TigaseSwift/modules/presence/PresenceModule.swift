//
// PresenceModule.swift
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
import Combine

extension XmppModuleIdentifier {
    public static var presence: XmppModuleIdentifier<PresenceModule> {
        return PresenceModule.IDENTIFIER;
    }
}

/**
 Module provides support for handling presence on client side
 as described in [RFC6121]
 
 [RFC6121]: http://xmpp.org/rfcs/rfc6121.html
 */
open class PresenceModule: XmppModuleBaseSessionStateAware, XmppModule, Resetable {
        
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "presence";
    public static let IDENTIFIER = XmppModuleIdentifier<PresenceModule>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "PresenceModule");
    
    public let criteria = Criteria.name("presence");
    
    public let features = [String]();
    
    /// Should initial presence be sent automatically
    open var initialPresence: Bool = true;
    
    /// Presence store with current presence informations
    public let store: PresenceStore;
    
    /// Should send presence changes events during stream resumption
    open var fireEventsOnStreamResumption = true;
    fileprivate var streamResumptionPresences: [Presence]? = nil;
    
    @Published
    public private(set) var presence: Presence = Presence();
    
    public let presencePublisher = PassthroughSubject<ContactPresenceChange,Never>();
    public let subscriptionPublisher = PassthroughSubject<SubscriptionChange,Never>();
    
    public init(store: PresenceStore = DefaultPresenceStore()) {
        self.store = store;
        super.init();
        self.presence.show = .online;
    }
        
    open func reset(scopes: Set<ResetableScope>) {
        if let context = context {
            store.reset(scopes: scopes, for: context);
        }
    }
        
    public override func stateChanged(newState: XMPPClient.State) {
        guard case .connected(let resumed) = newState, !resumed else {
            return;
        }

        if initialPresence {
            sendInitialPresence();
        }
    }
    
    open func process(stanza: Stanza) throws {
        if let presence = stanza as? Presence, let context = self.context {
            let type = presence.type ?? StanzaType.available;
            switch type {
            case .unavailable:
                if let jid = presence.from {
                    let availabilityChanged = store.removePresence(for: jid, context: context);
                    self.presencePublisher.send(.init(presence: presence, jid: jid, availabilityChanged: availabilityChanged));
                }
            case .available, .error:
                let availabilityChanged = store.update(presence: presence, for: context)?.type != presence.type;
                if let jid = presence.from {
                    self.presencePublisher.send(.init(presence: presence, jid: jid, availabilityChanged: availabilityChanged));
                }
            case .unsubscribed:
                if let jid = presence.from {
                    self.subscriptionPublisher.send(.init(action: .unsubscribed, jid: jid, presence: presence));
                }
            case .subscribe:
                if let jid = presence.from {
                    self.subscriptionPublisher.send(.init(action: .subscribe, jid: jid, presence: presence));
                }
            default:
                logger.error("received presence with weird type: \(type, privacy: .public), \(presence)");
            }
        }
    }
    
    /// Send initial presence
    open func sendInitialPresence() {
        self.presence = presence;
        write(presence);
    }
    
    open func sendPresence() {
        self.presence = presence;
        write(presence);
    }
    
    /**
     Send presence with value
     - parameter show: presence show
     - parameter status: additional text description
     - parameter priority: priority of presence
     - parameter additionalElements: array of additional elements which should be added to presence
     */
    open func setPresence(show:Presence.Show?, status:String?, priority:Int?, additionalElements: [Element]? = nil) {
        let presence = Presence();
        presence.show = show;
        presence.status = status;
        presence.priority = priority;
        
        if let nick: String = context?.connectionConfiguration.nickname {
            presence.nickname = nick;
        }
        
        if let addons = additionalElements {
            presence.addChildren(addons);
        }
        
        self.presence = presence;
        if context?.state == .connected() {
            write(presence);
        }
    }
    
    /**
     Request subscription
     - parameter to: jid to request subscription
     */
    open func subscribe(to jid:JID, preauth: String? = nil) {
        let presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribe;
        if preauth != nil {
            presence.addChild(Element(name: "preauth", attributes: ["xmlns": "urn:xmpp:pars:0", "token": preauth!]));
        }
        
        write(presence);
    }

    /**
     Subscribed to JID
     - parameter by: jid which is being subscribed
     */
    open func subscribed(by jid:JID) {
        let presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribed;
        
        write(presence);
    }

    /**
     Unsubscribe from jid
     - parameter from: jid to unsubscribe from
     */
    open func unsubscribe(from jid:JID) {
        let presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.unsubscribe;
        
        write(presence);
    }
    
    /**
     Unsubscribed from JID
     - parameter by: jid which is being unsubscribed
     */
    open func unsubscribed(by jid:JID) {
        let presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.unsubscribed;
        
        write(presence);
    }

    public struct SubscriptionChange {
    
        public let action: Action;
        public let jid: JID;
        public let presence: Presence;
        
        public enum Action {
            case subscribe
            case unsubscribed
        }
    }
 
    public struct ContactPresenceChange {
        
        public let presence: Presence;
        public let jid: JID;
        public let availabilityChanged: Bool;
        
    }
}
