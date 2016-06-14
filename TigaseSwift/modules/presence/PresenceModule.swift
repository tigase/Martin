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

/**
 Module provides support for handling presence on client side
 as described in [RFC6121]
 
 [RFC6121]: http://xmpp.org/rfcs/rfc6121.html
 */
public class PresenceModule: Logger, XmppModule, ContextAware, EventHandler, Initializable {
    
    public static let INITIAL_PRESENCE_ENABLED_KEY = "initalPresenceEnabled";
    public static let PRESENCE_STORE_KEY = "presenceStore";
    
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "presence";
    
    public let id = ID;
    
    public let criteria = Criteria.name("presence");
    
    public let features = [String]();
    
    public var context:Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(self, events: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, SessionObject.ClearedEvent.TYPE);
            }
            if context != nil {
                context.eventBus.register(self, events: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, SessionObject.ClearedEvent.TYPE);
            }
        }
    }
    
    /// Should initial presence be sent automatically
    public var initialPresence:Bool {
        get {
            return context.sessionObject.getProperty(PresenceModule.INITIAL_PRESENCE_ENABLED_KEY, defValue: true);
        }
        set {
            context.sessionObject.setProperty(PresenceModule.INITIAL_PRESENCE_ENABLED_KEY, value: newValue);
        }
    }
    
    /// Presence store with current presence informations
    public var presenceStore:PresenceStore {
        get {
            return PresenceModule.getPresenceStore(context.sessionObject);
        }
    }
    
    public static func getPresenceStore(sessionObject:SessionObject) -> PresenceStore {
        let presenceStore:PresenceStore = sessionObject.getProperty(PRESENCE_STORE_KEY)!;
        return presenceStore;
    }
    
    
    public override init() {
        
    }
    
    public func initialize() {
        var presenceStoreTmp:PresenceStore? = context.sessionObject.getProperty(PresenceModule.PRESENCE_STORE_KEY);
        if presenceStoreTmp == nil {
            presenceStoreTmp = PresenceStore();
            context.sessionObject.setProperty(PresenceModule.PRESENCE_STORE_KEY, value: presenceStoreTmp, scope: .user);
        }
        
        presenceStore.setHandler(PresenceStoreHandlerImpl(presenceModule:self));
    }
    
    public func handleEvent(event: Event) {
        switch event {
        case is SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            if initialPresence {
                sendInitialPresence();
            } else {
                log("skipping sending initial presence");
            }
        case let ce as SessionObject.ClearedEvent:
            if ce.scopes.contains(.session) {
                presenceStore.clear();
            }
        default:
            log("received unknown event", event);
        }
    }
    
    public func process(stanza: Stanza) throws {
        if let presence = stanza as? Presence {
            let type = presence.type ?? StanzaType.available;
            switch type {
            case .available, .unavailable, .error:
                let availabilityChanged = presenceStore.update(presence);
                context.eventBus.fire(ContactPresenceChanged(sessionObject: context.sessionObject, presence: presence, availabilityChanged: availabilityChanged));
            case .unsubscribed:
                context.eventBus.fire(ContactUnsubscribedEvent(sessionObject: context.sessionObject, presence: presence));
            case .subscribe:
                context.eventBus.fire(SubscribeRequestEvent(sessionObject: context.sessionObject, presence: presence));
            default:
                log("received presence with weird type:", type, presence);
            }
        }
    }
    
    /// Send initial presence
    public func sendInitialPresence() {
        setPresence(.online, status: nil, priority: nil);
    }
    
    /**
     Send presence with value
     - parameter show: presence show
     - parameter status: additional text description
     - parameter priority: priority of presence
     - parameter additionalElements: array of additional elements which should be added to presence
     */
    public func setPresence(show:Presence.Show, status:String?, priority:Int?, additionalElements: [Element]? = nil) {
        var presence = Presence();
        presence.show = show;
        presence.status = status;
        presence.priority = priority;
        
        if let nick:String = context.sessionObject.getProperty(SessionObject.NICKNAME) {
            presence.nickname = nick;
        }
        
        if additionalElements != nil {
            presence.addChildren(additionalElements!);
        }
        context.eventBus.fire(BeforePresenceSendEvent(sessionObject: context.sessionObject, presence: presence));
        
        context.writer?.write(presence);
    }
    
    /**
     Request subscription
     - parameter jid: jid to request subscription
     */
    public func subscribe(jid:JID) {
        var presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribe;
        
        context.writer?.write(presence);
    }

    /**
     Subscribe JID
     - parameter jid: jid to subscribe
     */
    public func subscribed(jid:JID) {
        var presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribed;
        
        context.writer?.write(presence);
    }

    /**
     Unsubscribe from jid
     - parameter jid: jid to unsubscribe from
     */
    public func unsubscribe(jid:JID) {
        var presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.unsubscribe;
        
        context.writer?.write(presence);
    }
    
    /**
     Unsubscribed JID
     - parameter jid: jid which is being unsubscribed
     */
    public func unsubscribed(jid:JID) {
        var presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.unsubscribed;
        
        context.writer?.write(presence);
    }
    
    /**
     Event fired before presence is being sent.
     
     In handlers receiving this event it is possible to change
     value of presence which will allow to change presence
     which is going to be sent.
     */
    public class BeforePresenceSendEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = BeforePresenceSendEvent();
        
        public let type = "BeforePresenceSendEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Presence which will be send
        public let presence:Presence!;
        
        private init() {
            self.sessionObject = nil;
            self.presence = nil;
        }
        
        public init(sessionObject:SessionObject, presence:Presence) {
            self.sessionObject = sessionObject;
            self.presence = presence;
        }
        
    }

    /// Event fired when contact changes presence
    public class ContactPresenceChanged: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ContactPresenceChanged();
        
        public let type = "ContactPresenceChanged";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Received presence
        public let presence:Presence!;
        /// Contact become online or offline
        public let availabilityChanged:Bool;
        
        private init() {
            self.sessionObject = nil;
            self.presence = nil;
            self.availabilityChanged = false;
        }
        
        public init(sessionObject:SessionObject, presence:Presence, availabilityChanged:Bool) {
            self.sessionObject = sessionObject;
            self.presence = presence;
            self.availabilityChanged = availabilityChanged;
        }
        
    }

    /// Event fired if we are unsubscribed from someone presence
    public class ContactUnsubscribedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ContactUnsubscribedEvent();
        
        public let type = "ContactUnsubscribedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Presence received
        public let presence:Presence!;
        
        private init() {
            self.sessionObject = nil;
            self.presence = nil;
        }
        
        public init(sessionObject:SessionObject, presence:Presence) {
            self.sessionObject = sessionObject;
            self.presence = presence;
        }
        
    }
    
    /// Event fired if someone wants to subscribe our presence
    public class SubscribeRequestEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SubscribeRequestEvent();
        
        public let type = "SubscribeRequestEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Presence received
        public let presence:Presence!;
        
        private init() {
            self.sessionObject = nil;
            self.presence = nil;
        }
        
        public init(sessionObject:SessionObject, presence:Presence) {
            self.sessionObject = sessionObject;
            self.presence = presence;
        }
    }
    
    /// Implementation of `PresenceStoreHandler` using `PresenceModule`
    public class PresenceStoreHandlerImpl: PresenceStoreHandler {
        
        let presenceModule:PresenceModule;
        
        public init(presenceModule:PresenceModule) {
            self.presenceModule = presenceModule;
        }
        
        public func onOffline(presence: Presence) {
            var offlinePresence = Presence();
            offlinePresence.type = StanzaType.unavailable;
            offlinePresence.from = JID(presence.from!.bareJid);
            presenceModule.context.eventBus.fire(ContactPresenceChanged(sessionObject: presenceModule.context.sessionObject, presence: offlinePresence, availabilityChanged: true));
        }
        
        public func setPresence(show: Presence.Show, status: String?, priority: Int?) {
            presenceModule.setPresence(show, status: status, priority: priority);
        }
    }
}