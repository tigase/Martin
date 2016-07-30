//
// RosterModule.swift
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
 Module provides roster manipulation features as described in [RFC6121]
 
 [RFC6121]: http://xmpp.org/rfcs/rfc6121.html#roster
 */
public class RosterModule: Logger, AbstractIQModule, ContextAware, EventHandler, Initializable {
    
    public static let ROSTER_STORE_KEY = "rosterStore";
    /// ID of module for looup in `XmppModulesManager`
    public static let ID = "roster";
    
    public let id = ID;
    
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
    
    public let criteria = Criteria.name("iq").add(Criteria.name("query", xmlns: "jabber:iq:roster"));
    
    public let features = [String]();
    /// Roster cache versio provider
    public var versionProvider:RosterCacheProvider?;
    /// Roster store
    public var rosterStore:RosterStore {
        get {
            return RosterModule.getRosterStore(context.sessionObject);
        }
        set {
            context.sessionObject.setProperty(RosterModule.ROSTER_STORE_KEY, value: newValue, scope: .user);
        }
    }
    
    public static func getRosterStore(sessionObject:SessionObject) -> RosterStore {
        let rosterStore:RosterStore? = sessionObject.getProperty(ROSTER_STORE_KEY);
        return rosterStore!;
    }
    
    public override init() {
        
    }
    
    public func initialize() {
        var rosterStoreTmp:RosterStore? = context.sessionObject.getProperty(RosterModule.ROSTER_STORE_KEY);
        if rosterStoreTmp == nil {
            rosterStoreTmp = DefaultRosterStore();
            context.sessionObject.setProperty(RosterModule.ROSTER_STORE_KEY, value: rosterStoreTmp, scope: .user);
        }
        
        rosterStore.handler = RosterStoreHandlerImpl(module: self);
        loadFromCache();
    }
    
    public func handleEvent(event: Event) {
        switch event {
        case is SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            rosterRequest();
        case let ce as SessionObject.ClearedEvent:
            if ce.scopes.contains(.user) {
                rosterStore.cleared();
                context.eventBus.fire(ItemUpdatedEvent(sessionObject: context.sessionObject, rosterItem: nil, action: .removed, modifiedGroups: nil));
            }
        default:
            log("received unknown event", event);
        }
    }
    
    public func processGet(stanza: Stanza) throws {
        throw ErrorCondition.not_allowed;
    }
    
    public func processSet(stanza: Stanza) throws {
        let bindedJid = ResourceBinderModule.getBindedJid(context.sessionObject);
        if (stanza.from != nil && stanza.from != bindedJid) {
            throw ErrorCondition.not_allowed;
        }
        
        if let query = stanza.findChild("query", xmlns: "jabber:iq:roster") {
            processRosterQuery(query, force: false);
        }
    }
    
    private func processRosterQuery(query:Element, force:Bool) {
        if force {
            rosterStore.removeAll();
        }
        
        let ver = query.getAttribute("ver");
        query.forEachChild("item") { (item:Element) -> Void in
            self.processRosterItem(item);
        }
    
        if ver != nil {
            versionProvider?.updateReceivedVersion(context.sessionObject, ver: ver);
        }
        
    }
    
    private func processRosterItem(item:Element) {
        let jid = JID(item.getAttribute("jid")!);
        let name = item.getAttribute("name");
        let subscription:RosterItem.Subscription = item.getAttribute("subscription") == nil ? RosterItem.Subscription.none : RosterItem.Subscription(rawValue: item.getAttribute("subscription")!)!;
        let ask = item.getAttribute("ask") == "subscribe";
        let groups:[String] = item.mapChildren({(g:Element) -> String in
                return g.value!;
            }, filter: {(e:Element) -> Bool in
                return e.name == "group";
            });
        
        var currentItem = rosterStore.get(jid);
        var action = Action.other;
        var modifiedGroups:[String]? = nil;
        if (subscription == .remove && currentItem != nil) {
            rosterStore.removeItem(jid);
            action = .removed;
            modifiedGroups = currentItem!.groups;
        } else {
            if (currentItem == nil) {
                action = .added;
            } else {
                if (currentItem!.ask == ask && (subscription == .from || subscription == .none)) {
                    action = .askCancelled;
                } else {
                    if (currentItem!.subscription.isFrom == subscription.isFrom) {
                        action = (currentItem!.subscription.isTo && subscription.isTo == false) ? .unsubscribed : .subscribed;
                    }
                }
            }
            
            var modifiedGroups:[String]? = nil;
            if currentItem != nil && (action == .other || action == .added) {
                modifiedGroups = currentItem!.groups.filter({(gname:String)->Bool in
                    return !groups.contains(gname);
                });
                modifiedGroups?.appendContentsOf(groups.filter({(gname:String)->Bool in
                    return !currentItem!.groups.contains(gname);
                }));
            }
            currentItem = currentItem != nil ? currentItem!.update(name, subscription: subscription, groups: groups, ask: ask) : RosterItem(jid: jid, name: name, subscription: subscription, groups: groups, ask: ask);
            
            rosterStore.addItem(currentItem!);
            
        }
        fire(ItemUpdatedEvent(sessionObject: context.sessionObject, rosterItem: currentItem!, action: action, modifiedGroups: modifiedGroups));
    }
    
    /**
     Send roster retrieval request to server
     */
    public func rosterRequest() {
        var iq = Iq();
        iq.type = .get;
        var query = Element(name:"query", xmlns:"jabber:iq:roster");
        
        if isRosterVersioningAvailable() {
            var x = versionProvider?.getCachedVersion(context.sessionObject) ?? "";
            if (rosterStore.count == 0) {
                x = "";
                versionProvider?.updateReceivedVersion(context.sessionObject, ver: x);
            }
            query.setAttribute("ver", value: x);
        }
        iq.addChild(query);
        
        context.writer?.write(iq, callback: { (result:Stanza?) in
            if (result?.type == StanzaType.result) {
                if let query = result!.findChild("query", xmlns: "jabber:iq:roster") {
                    self.processRosterQuery(query, force: true);
                }
            }
        })
    }
    
    func updateItem(jid:JID, name:String?, groups:[String], subscription:RosterItem.Subscription? = nil, onSuccess:((stanza:Stanza)->Void)?, onError:((errorCondition:ErrorCondition?)->Void)?) {
        var iq = Iq();
        iq.type = .set;
        
        var query = Element(name:"query", xmlns:"jabber:iq:roster");
        iq.addChild(query);
        
        var item = Element(name: "item");
        item.setAttribute("jid", value: jid.stringValue);
        item.setAttribute("name", value: name);
        groups.forEach({(group:String)->Void in
            item.addChild(Element(name:"group", cdata:group));
        });
        
        if subscription == RosterItem.Subscription.remove {
            item.setAttribute("subscription", value: "remove");
        }
        query.addChild(item);
        
        context.writer?.write(iq, callback: {(result:Stanza?) -> Void in
            if result?.type == StanzaType.result {
                onSuccess?(stanza: result!);
            } else {
                onError?(errorCondition: result?.errorCondition);
            }
        });
    }
    
    private func fire(event:Event) {
        context.eventBus.fire(event);
    }
    
    private func isRosterVersioningAvailable() -> Bool {
        if (versionProvider == nil) {
            return false;
        }
        return StreamFeaturesModule.getStreamFeatures(context.sessionObject)?.findChild("ver", xmlns: "urn:xmpp:features:rosterver") != nil;
    }
    
    private func loadFromCache() {
        if versionProvider != nil {
            let store = rosterStore;
            versionProvider?.loadCachedRoster(context.sessionObject).forEach({ (item:RosterItem) in
                store.addItem(item);
            })
        }
    }
    
    /**
     Actions which could happen to roster items:
     - added: item was added
     - askCanceled: item was pending subscription request
     - removed: item was removed
     - subscribed: item got subscribed
     - unsubscribed: item got unsubscribed
     - other: other actions not defined above
     */
    public enum Action {
        case added
        case askCancelled
        case removed
        case subscribed
        case unsubscribed
        case other
    }

    /// Event fired when roster item is updated
    public class ItemUpdatedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ItemUpdatedEvent();
        
        public let type = "ItemUpdatedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Changed roster item
        public let rosterItem:RosterItem?;
        /// Action done to roster item
        public let action:Action!;
        /// Groups which were modified
        public let modifiedGroups:[String]?;
        
        private init() {
            self.sessionObject = nil;
            self.rosterItem = nil;
            self.action = nil;
            self.modifiedGroups = nil;
        }
        
        public init(sessionObject:SessionObject, rosterItem: RosterItem?, action:Action, modifiedGroups:[String]?) {
            self.sessionObject = sessionObject;
            self.rosterItem = rosterItem;
            self.action = action;
            self.modifiedGroups = modifiedGroups;
        }
    }

    /// Implementation of `RosterStoreHandler` protocol using `RosterModule`
    class RosterStoreHandlerImpl: RosterStoreHandler {
        let rosterModule:RosterModule;
        
        init(module:RosterModule) {
            self.rosterModule = module;
        }
        
        func add(jid: JID, name: String?, groups: [String], onSuccess: ((stanza: Stanza) -> Void)?, onError: ((errorCondition: ErrorCondition?) -> Void)?) {
            self.rosterModule.updateItem(jid, name: name, groups: groups, onSuccess: onSuccess, onError: onError);
        }
        
        func remove(jid: JID, onSuccess: ((stanza: Stanza) -> Void)?, onError: ((errorCondition: ErrorCondition?) -> Void)?) {
            self.rosterModule.updateItem(jid, name: nil, groups: [String](), subscription: RosterItem.Subscription.remove, onSuccess: onSuccess, onError: onError);
        }
        
        func update(item: RosterItem, name: String?, groups: [String]? = nil, onSuccess: ((stanza: Stanza) -> Void)?, onError: ((errorCondition: ErrorCondition?) -> Void)?) {
            self.rosterModule.updateItem(item.jid, name: name, groups: groups ?? item.groups, onSuccess: onSuccess, onError: onError);
        }

        func update(item: RosterItem, groups: [String], onSuccess: ((stanza: Stanza) -> Void)?, onError: ((errorCondition: ErrorCondition?) -> Void)?) {
            self.rosterModule.updateItem(item.jid, name: item.name, groups: groups, onSuccess: onSuccess, onError: onError);
        }
        
        func cleared() {
            self.rosterModule.loadFromCache();
        }
    }
}