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
open class PresenceModule: Logger, XmppModule, ContextAware, EventHandler, Initializable {
    
    public static let INITIAL_PRESENCE_ENABLED_KEY = "initalPresenceEnabled";
    public static let PRESENCE_STORE_KEY = "presenceStore";
    
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "presence";
    
    public let id = ID;
    
    public let criteria = Criteria.name("presence");
    
    public let features = [String]();
    
    open var context:Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, StreamManagementModule.ResumedEvent.TYPE, StreamManagementModule.FailedEvent.TYPE, SessionObject.ClearedEvent.TYPE);
            }
            if context != nil {
                context.eventBus.register(handler: self, for: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, StreamManagementModule.ResumedEvent.TYPE, StreamManagementModule.FailedEvent.TYPE, SessionObject.ClearedEvent.TYPE);
            }
        }
    }
    
    /// Should initial presence be sent automatically
    open var initialPresence:Bool {
        get {
            return context.sessionObject.getProperty(PresenceModule.INITIAL_PRESENCE_ENABLED_KEY, defValue: true);
        }
        set {
            context.sessionObject.setUserProperty(PresenceModule.INITIAL_PRESENCE_ENABLED_KEY, value: newValue);
        }
    }
    
    /// Presence store with current presence informations
    open var presenceStore:PresenceStore {
        get {
            return PresenceModule.getPresenceStore(context.sessionObject);
        }
    }
    
    /// Should send presence changes events during stream resumption
    open var fireEventsOnStreamResumption = true;
    fileprivate var streamResumptionPresences: [Presence]? = nil;
    
    public static func getPresenceStore(_ sessionObject:SessionObject) -> PresenceStore {
        let presenceStore:PresenceStore = sessionObject.getProperty(PRESENCE_STORE_KEY)!;
        return presenceStore;
    }
    
    
    public override init() {
        
    }
    
    open func initialize() {
        var presenceStoreTmp:PresenceStore? = context.sessionObject.getProperty(PresenceModule.PRESENCE_STORE_KEY);
        if presenceStoreTmp == nil {
            presenceStoreTmp = PresenceStore();
            context.sessionObject.setProperty(PresenceModule.PRESENCE_STORE_KEY, value: presenceStoreTmp, scope: .user);
        }
        
        presenceStore.setHandler(PresenceStoreHandlerImpl(presenceModule:self));
    }
    
    open func handle(event: Event) {
        switch event {
        case is SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            self.streamResumptionPresences = nil;
            if initialPresence {
                sendInitialPresence();
            } else {
                log("skipping sending initial presence");
            }
        case is StreamManagementModule.ResumedEvent:
            self.streamResumptionPresences?.forEach { presence in
                let availabilityChanged = presenceStore.update(presence: presence);
                context.eventBus.fire(ContactPresenceChanged(sessionObject: context.sessionObject, presence: presence, availabilityChanged: availabilityChanged));
            }
            self.streamResumptionPresences = nil;
        case is StreamManagementModule.FailedEvent:
            self.streamResumptionPresences = nil;
        case let ce as SessionObject.ClearedEvent:
            if ce.scopes.contains(.session) {
                presenceStore.clear();
            } else if ce.scopes.contains(.stream) && self.fireEventsOnStreamResumption {
                self.streamResumptionPresences = presenceStore.getAllPresences();
                presenceStore.clear();
            }
        default:
            log("received unknown event", event);
        }
    }
    
    open func process(stanza: Stanza) throws {
        if let presence = stanza as? Presence {
            let type = presence.type ?? StanzaType.available;
            switch type {
            case .available, .unavailable, .error:
                let availabilityChanged = presenceStore.update(presence: presence);
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
    open func sendInitialPresence() {
        setPresence(show: .online, status: nil, priority: nil);
    }
    
    /**
     Send presence with value
     - parameter show: presence show
     - parameter status: additional text description
     - parameter priority: priority of presence
     - parameter additionalElements: array of additional elements which should be added to presence
     */
    open func setPresence(show:Presence.Show, status:String?, priority:Int?, additionalElements: [Element]? = nil) {
        let presence = Presence();
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
     - parameter to: jid to request subscription
     */
    open func subscribe(to jid:JID) {
        let presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribe;
        
        context.writer?.write(presence);
    }

    /**
     Subscribed to JID
     - parameter by: jid which is being subscribed
     */
    open func subscribed(by jid:JID) {
        let presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribed;
        
        context.writer?.write(presence);
    }

    /**
     Unsubscribe from jid
     - parameter from: jid to unsubscribe from
     */
    open func unsubscribe(from jid:JID) {
        let presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.unsubscribe;
        
        context.writer?.write(presence);
    }
    
    /**
     Unsubscribed from JID
     - parameter by: jid which is being unsubscribed
     */
    open func unsubscribed(by jid:JID) {
        let presence = Presence();
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
    open class BeforePresenceSendEvent: Event, SerialEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = BeforePresenceSendEvent();
        
        public let type = "BeforePresenceSendEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Presence which will be send
        public let presence:Presence!;
        
        fileprivate init() {
            self.sessionObject = nil;
            self.presence = nil;
        }
        
        public init(sessionObject:SessionObject, presence:Presence) {
            self.sessionObject = sessionObject;
            self.presence = presence;
        }
        
    }

    /// Event fired when contact changes presence
    open class ContactPresenceChanged: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ContactPresenceChanged();
        
        public let type = "ContactPresenceChanged";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Received presence
        public let presence:Presence!;
        /// Contact become online or offline
        public let availabilityChanged:Bool;
        
        fileprivate init() {
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
    open class ContactUnsubscribedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ContactUnsubscribedEvent();
        
        public let type = "ContactUnsubscribedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Presence received
        public let presence:Presence!;
        
        fileprivate init() {
            self.sessionObject = nil;
            self.presence = nil;
        }
        
        public init(sessionObject:SessionObject, presence:Presence) {
            self.sessionObject = sessionObject;
            self.presence = presence;
        }
        
    }
    
    /// Event fired if someone wants to subscribe our presence
    open class SubscribeRequestEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SubscribeRequestEvent();
        
        public let type = "SubscribeRequestEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Presence received
        public let presence:Presence!;
        
        fileprivate init() {
            self.sessionObject = nil;
            self.presence = nil;
        }
        
        public init(sessionObject:SessionObject, presence:Presence) {
            self.sessionObject = sessionObject;
            self.presence = presence;
        }
    }
    
    /// Implementation of `PresenceStoreHandler` using `PresenceModule`
    open class PresenceStoreHandlerImpl: PresenceStoreHandler {
        
        let presenceModule:PresenceModule;
        
        public init(presenceModule:PresenceModule) {
            self.presenceModule = presenceModule;
        }
        
        open func onOffline(presence: Presence) {
            let offlinePresence = Presence();
            offlinePresence.type = StanzaType.unavailable;
            offlinePresence.from = JID(presence.from!.bareJid);
            presenceModule.context.eventBus.fire(ContactPresenceChanged(sessionObject: presenceModule.context.sessionObject, presence: offlinePresence, availabilityChanged: true));
        }
        
        open func setPresence(show: Presence.Show, status: String?, priority: Int?) {
            presenceModule.setPresence(show: show, status: status, priority: priority);
        }
    }
}
