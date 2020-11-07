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
open class PresenceModule: XmppModule, ContextAware, EventHandler {
        
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "presence";
    public static let IDENTIFIER = XmppModuleIdentifier<PresenceModule>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "PresenceModule");
    
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
    open var initialPresence: Bool = true;
    
    /// Presence store with current presence informations
    public let store: PresenceStore;
    @available(*, deprecated, renamed: "store")
    public var presenceStore: PresenceStore {
        return store;
    }
    
    /// Should send presence changes events during stream resumption
    open var fireEventsOnStreamResumption = true;
    fileprivate var streamResumptionPresences: [Presence]? = nil;
    
    @available(*, deprecated, message: "Use store property of the module instance directly!")
    public static func getPresenceStore(_ sessionObject:SessionObject) -> PresenceStore {
        return sessionObject.context.module(.presence).store;
    }
    
    public init(store: PresenceStore = PresenceStore()) {
        self.store = store;
        store.handler = PresenceStoreHandlerImpl(presenceModule: self);
    }
        
    open func handle(event: Event) {
        switch event {
        case is SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            self.streamResumptionPresences = nil;
            if initialPresence {
                sendInitialPresence();
            } else {
                logger.debug("skipping sending initial presence");
            }
        case is StreamManagementModule.ResumedEvent:
            self.streamResumptionPresences?.forEach { presence in
                let availabilityChanged = store.update(presence: presence);
                context.eventBus.fire(ContactPresenceChanged(context: context, presence: presence, availabilityChanged: availabilityChanged));
            }
            self.streamResumptionPresences = nil;
        case is StreamManagementModule.FailedEvent:
            self.streamResumptionPresences = nil;
        case let ce as SessionObject.ClearedEvent:
            if ce.scopes.contains(.session) {
                store.clear();
            } else if ce.scopes.contains(.stream) && self.fireEventsOnStreamResumption {
                self.streamResumptionPresences = store.getAllPresences();
                store.clear();
            }
        default:
            logger.error("received unknown event: \(event)");
        }
    }
    
    open func process(stanza: Stanza) throws {
        if let presence = stanza as? Presence {
            let type = presence.type ?? StanzaType.available;
            switch type {
            case .available, .unavailable, .error:
                let availabilityChanged = store.update(presence: presence);
                context.eventBus.fire(ContactPresenceChanged(context: context, presence: presence, availabilityChanged: availabilityChanged));
            case .unsubscribed:
                context.eventBus.fire(ContactUnsubscribedEvent(context: context, presence: presence));
            case .subscribe:
                context.eventBus.fire(SubscribeRequestEvent(context: context, presence: presence));
            default:
                logger.error("received presence with weird type: \(type, privacy: .public), \(presence)");
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
        
        if let nick: String = context.connectionConfiguration.nickname {
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
    open func subscribe(to jid:JID, preauth: String? = nil) {
        let presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribe;
        if preauth != nil {
            presence.addChild(Element(name: "preauth", attributes: ["xmlns": "urn:xmpp:pars:0", "token": preauth!]));
        }
        
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
    open class ContactPresenceChanged: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ContactPresenceChanged();
        
        /// Received presence
        public let presence:Presence!;
        /// Contact become online or offline
        public let availabilityChanged:Bool;
        
        fileprivate init() {
            self.presence = nil;
            self.availabilityChanged = false;
            super.init(type: "ContactPresenceChanged")
        }
        
        public init(context: Context, presence: Presence, availabilityChanged: Bool) {
            self.presence = presence;
            self.availabilityChanged = availabilityChanged;
            super.init(type: "ContactPresenceChanged", context: context);
        }
        
    }

    /// Event fired if we are unsubscribed from someone presence
    open class ContactUnsubscribedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ContactUnsubscribedEvent();
        
        /// Presence received
        public let presence:Presence!;
        
        fileprivate init() {
            self.presence = nil;
            super.init(type: "ContactUnsubscribedEvent")
        }
        
        public init(context: Context, presence:Presence) {
            self.presence = presence;
            super.init(type: "ContactUnsubscribedEvent", context: context);
        }
        
    }
    
    /// Event fired if someone wants to subscribe our presence
    open class SubscribeRequestEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SubscribeRequestEvent();
        
        /// Presence received
        public let presence:Presence!;
        
        fileprivate init() {
            self.presence = nil;
            super.init(type: "SubscribeRequestEvent");
        }
        
        public init(context: Context, presence: Presence) {
            self.presence = presence;
            super.init(type: "SubscribeRequestEvent", context: context)
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
            presenceModule.context.eventBus.fire(ContactPresenceChanged(context: presenceModule.context, presence: offlinePresence, availabilityChanged: true));
        }
        
        open func setPresence(show: Presence.Show, status: String?, priority: Int?) {
            presenceModule.setPresence(show: show, status: status, priority: priority);
        }
    }
}
