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

public class PresenceModule: Logger, XmppModule, ContextAware, EventHandler, Initializable {
    
    public static let INITIAL_PRESENCE_ENABLED_KEY = "initalPresenceEnabled";
    public static let PRESENCE_STORE_KEY = "presenceStore";
    
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
    
    public var initialPresence:Bool {
        get {
            return context.sessionObject.getProperty(PresenceModule.INITIAL_PRESENCE_ENABLED_KEY, defValue: true);
        }
        set {
            context.sessionObject.setProperty(PresenceModule.INITIAL_PRESENCE_ENABLED_KEY, value: newValue);
        }
    }
    
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
        case is SessionObject.ClearedEvent:
            presenceStore.clear();
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
    
    public func sendInitialPresence() {
        var presence = Presence();
        if let nick:String = context.sessionObject.getProperty(SessionObject.NICKNAME) {
            presence.nickname = nick;
        }
        
        context.eventBus.fire(BeforePresenceSendEvent());
        
        context.writer?.write(presence);
    }
    
    public func setPresence(show:Presence.Show, status:String?, priority:Int?) {
        var presence = Presence();
        presence.show = show;
        presence.status = status;
        presence.priority = priority;
        
        if let nick:String = context.sessionObject.getProperty(SessionObject.NICKNAME) {
            presence.nickname = nick;
        }
        
        context.eventBus.fire(BeforePresenceSendEvent());
        
        context.writer?.write(presence);
    }
    
    public func subscribe(jid:JID) {
        var presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribe;
        
        context.writer?.write(presence);
    }

    public func subscribed(jid:JID) {
        var presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.subscribed;
        
        context.writer?.write(presence);
    }

    public func unsubscribe(jid:JID) {
        var presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.unsubscribe;
        
        context.writer?.write(presence);
    }
    
    public func unsubscribed(jid:JID) {
        var presence = Presence();
        presence.to = jid;
        presence.type = StanzaType.unsubscribed;
        
        context.writer?.write(presence);
    }
    
    public class BeforePresenceSendEvent: Event {
        
        public static let TYPE = BeforePresenceSendEvent();
        
        public let type = "BeforePresenceSendEvent";
        
        public let sessionObject:SessionObject!;
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

    public class ContactPresenceChanged: Event {
        
        public static let TYPE = ContactPresenceChanged();
        
        public let type = "ContactPresenceChanged";
        
        public let sessionObject:SessionObject!;
        public let presence:Presence!;
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

    public class ContactUnsubscribedEvent: Event {
        
        public static let TYPE = ContactUnsubscribedEvent();
        
        public let type = "ContactUnsubscribedEvent";
        
        public let sessionObject:SessionObject!;
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
    
    public class SubscribeRequestEvent: Event {
        
        public static let TYPE = SubscribeRequestEvent();
        
        public let type = "SubscribeRequestEvent";
        
        public let sessionObject:SessionObject!;
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