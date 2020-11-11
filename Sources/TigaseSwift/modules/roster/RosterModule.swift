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
import TigaseLogging

extension XmppModuleIdentifier {
    public static var roster: XmppModuleIdentifier<RosterModule> {
        return RosterModule.IDENTIFIER;
    }
}

/**
 Module provides roster manipulation features as described in [RFC6121]
 
 [RFC6121]: http://xmpp.org/rfcs/rfc6121.html#roster
 */
open class RosterModule: AbstractIQModule, ContextAware, EventHandler {
    
    public static let IDENTIFIER = XmppModuleIdentifier<RosterModule>();
    /// ID of module for looup in `XmppModulesManager`
    public static let ID = "roster";
    
    public let logger = Logger(subsystem: "TigaseSwift", category: "RosterModule");
    
    open var context:Context! {
        didSet {
            if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, SessionObject.ClearedEvent.TYPE);
            }
            if context != nil {
                context.eventBus.register(handler: self, for: SessionEstablishmentModule.SessionEstablishmentSuccessEvent.TYPE, SessionObject.ClearedEvent.TYPE);
            }
        }
    }
    
    public let criteria = Criteria.name("iq").add(Criteria.name("query", xmlns: "jabber:iq:roster"));
    
    public let features = [String]();
    /// Roster cache versio provider
    open var versionProvider: RosterCacheProvider?;
    /// Roster store
    public let store: RosterStore;
    @available(* , deprecated, renamed: "store")
    public var rosterStore: RosterStore {
        return store;
    }

    @available(*, deprecated, message: "Use store property of the module instance directly!")
    public static func getRosterStore(_ sessionObject:SessionObject) -> RosterStore {
        return sessionObject.context.module(.roster).store;
    }
    
    public init(store: RosterStore = DefaultRosterStore()) {
        self.store = store;
        store.handler = RosterStoreHandlerImpl(module: self);
        loadFromCache();
    }
    
    open func handle(event: Event) {
        switch event {
        case is SessionEstablishmentModule.SessionEstablishmentSuccessEvent:
            rosterRequest();
        case let ce as SessionObject.ClearedEvent:
            if ce.scopes.contains(.user) {
                store.cleared();
                context.eventBus.fire(ItemUpdatedEvent(context: context, rosterItem: nil, action: .removed, modifiedGroups: nil));
            }
        default:
            logger.error("received unknown event: \(event)");
        }
    }
    
    open func processGet(stanza: Stanza) throws {
        throw XMPPError.feature_not_implemented;
    }
    
    open func processSet(stanza: Stanza) throws {
        let bindedJid = ResourceBinderModule.getBindedJid(context.sessionObject);
        if (stanza.from != nil && stanza.from != bindedJid && (stanza.from?.bareJid != bindedJid?.bareJid)) {
            throw XMPPError.not_allowed("You are not allowed to send this to me!");
        }
        
        if let query = stanza.findChild(name: "query", xmlns: "jabber:iq:roster") {
            processRosterQuery(query, force: false);
        }
    }
    
    fileprivate func processRosterQuery(_ query:Element, force:Bool) {
        if force {
            store.removeAll();
        }
        
        let ver = query.getAttribute("ver");
        query.forEachChild(name: "item") { (item:Element) -> Void in
            self.processRosterItem(item);
        }
    
        if ver != nil {
            versionProvider?.updateReceivedVersion(context.sessionObject, ver: ver);
        }
        
    }
    
    private func processRosterItem(_ item:Element) {
        let jid = JID(item.getAttribute("jid")!);
        let name = item.getAttribute("name");
        let subscription:RosterItem.Subscription = item.getAttribute("subscription") == nil ? RosterItem.Subscription.none : RosterItem.Subscription(rawValue: item.getAttribute("subscription")!)!;
        let ask = item.getAttribute("ask") == "subscribe";
        let groups:[String] = item.mapChildren(transform: {(g:Element) -> String in
                return g.value!;
            }, filter: {(e:Element) -> Bool in
                return e.name == "group" && e.value != nil;
            });
        
        var currentItem = store.get(for: jid);
        var action = Action.other;
        var modifiedGroups:[String]? = nil;
        let annotations: [RosterItemAnnotation] = processRosterItemForAnnotations(item: item);
        if (subscription == .remove && currentItem != nil) {
            store.removeItem(for: jid);
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
                modifiedGroups?.append(contentsOf: groups.filter({(gname:String)->Bool in
                    return !currentItem!.groups.contains(gname);
                }));
            }
            currentItem = currentItem != nil ? currentItem!.update(name: name, subscription: subscription, groups: groups, ask: ask, annotations: annotations) : RosterItem(jid: jid, name: name, subscription: subscription, groups: groups, ask: ask, annotations: annotations);
            
            store.addItem(currentItem!);
            
        }
        fire(ItemUpdatedEvent(context: context, rosterItem: currentItem!, action: action, modifiedGroups: modifiedGroups));
    }
    
    fileprivate func processRosterItemForAnnotations(item: Element) -> [RosterItemAnnotation] {
        return context.modulesManager.modules.map({ (module) -> RosterItemAnnotation? in
            if let aware = (module as? RosterAnnotationAwareProtocol) {
                return aware.process(rosterItemElem: item);
            } else {
                return nil;
            }
        }).filter({ $0 != nil}).map({ $0! });
    }
    
    /**
     Send roster retrieval request to server
     */
    @available(*, deprecated, renamed: "requestRoster")
    open func rosterRequest() {
        requestRoster(completionHandler: nil)
    }
    
    open func requestRoster(completionHandler: ((Result<Void, XMPPError>)->Void)? = nil) {
        let iq = Iq();
        iq.type = .get;
        let query = Element(name:"query", xmlns:"jabber:iq:roster");
        
        for module in context.modulesManager.modules {
            (module as? RosterAnnotationAwareProtocol)?.prepareRosterGetRequest(queryElem: query);
        }
        
        if isRosterVersioningAvailable() {
            var x = versionProvider?.getCachedVersion(context.sessionObject) ?? "";
            if (store.count == 0) {
                x = "";
                versionProvider?.updateReceivedVersion(context.sessionObject, ver: x);
            }
            query.setAttribute("ver", value: x);
        }
        iq.addChild(query);
        
        context.writer.write(iq, completionHandler: { result in
            switch result {
            case .success(let iq):
                if let query = iq.findChild(name: "query", xmlns: "jabber:iq:roster") {
                    self.processRosterQuery(query, force: true);
                }
            default:
                break;
            }
            completionHandler?(result.map({ _ in Void() }));
        })
    }
    
    func updateItem(_ jid:JID, name:String?, groups:[String], subscription:RosterItem.Subscription? = nil, completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
        let iq = Iq();
        iq.type = .set;
        
        let query = Element(name:"query", xmlns:"jabber:iq:roster");
        iq.addChild(query);
        
        let item = Element(name: "item");
        item.setAttribute("jid", value: jid.stringValue);
        if !(name?.isEmpty ?? true) {
            item.setAttribute("name", value: name);
        }
        groups.forEach({(group:String)->Void in
            item.addChild(Element(name:"group", cdata:group));
        });
        
        if subscription == RosterItem.Subscription.remove {
            item.setAttribute("subscription", value: "remove");
        }
        query.addChild(item);
        
        context.writer.write(iq, completionHandler: completionHandler);
    }
    
    fileprivate func fire(_ event:Event) {
        context.eventBus.fire(event);
    }
    
    fileprivate func isRosterVersioningAvailable() -> Bool {
        if (versionProvider == nil) {
            return false;
        }
        return StreamFeaturesModule.getStreamFeatures(context.sessionObject)?.findChild(name: "ver", xmlns: "urn:xmpp:features:rosterver") != nil;
    }
    
    fileprivate func loadFromCache() {
        if versionProvider != nil {
            let store = self.store;
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
    open class ItemUpdatedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ItemUpdatedEvent();
        
        /// Changed roster item
        public let rosterItem:RosterItem?;
        /// Action done to roster item
        public let action:Action!;
        /// Groups which were modified
        public let modifiedGroups:[String]?;
        
        fileprivate init() {
            self.rosterItem = nil;
            self.action = nil;
            self.modifiedGroups = nil;
            super.init(type: "ItemUpdatedEvent");
        }
        
        public init(context: Context, rosterItem: RosterItem?, action: Action, modifiedGroups: [String]?) {
            self.rosterItem = rosterItem;
            self.action = action;
            self.modifiedGroups = modifiedGroups;
            super.init(type: "ItemUpdatedEvent", context: context);
        }
    }

    /// Implementation of `RosterStoreHandler` protocol using `RosterModule`
    class RosterStoreHandlerImpl: RosterStoreHandler {
        let rosterModule:RosterModule;
        
        init(module:RosterModule) {
            self.rosterModule = module;
        }
        
        func add(jid: JID, name: String?, groups: [String], completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
            self.rosterModule.updateItem(jid, name: name, groups: groups, completionHandler: completionHandler);
        }
        
        func remove(jid: JID, completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
            self.rosterModule.updateItem(jid, name: nil, groups: [String](), subscription: RosterItem.Subscription.remove, completionHandler: completionHandler);
        }
        
        func update(item: RosterItem, name: String?, groups: [String]? = nil, completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
            self.rosterModule.updateItem(item.jid, name: name, groups: groups ?? item.groups, completionHandler: completionHandler);
        }

        func update(item: RosterItem, groups: [String], completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
            self.rosterModule.updateItem(item.jid, name: item.name, groups: groups, completionHandler: completionHandler);
        }
        
        func cleared() {
            self.rosterModule.loadFromCache();
        }
    }
    
}

protocol RosterAnnotationAwareProtocol {
    
    func prepareRosterGetRequest(queryElem el: Element);
    
    func process(rosterItemElem el: Element) -> RosterItemAnnotation?;
    
}
