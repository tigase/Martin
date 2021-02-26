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
import Combine

extension XmppModuleIdentifier {
    public static var roster: XmppModuleIdentifier<RosterModule> {
        return RosterModule.IDENTIFIER;
    }
}

extension StreamFeatures.StreamFeature {
    public static let rosterVersioning = StreamFeatures.StreamFeature(name: "ver", xmlns: "urn:xmpp:features:rosterver");
}

/**
 Module provides roster manipulation features as described in [RFC6121]
 
 [RFC6121]: http://xmpp.org/rfcs/rfc6121.html#roster
 */
open class RosterModule: XmppModuleBaseSessionStateAware, AbstractIQModule {
    
    public static let IDENTIFIER = XmppModuleIdentifier<RosterModule>();
    /// ID of module for looup in `XmppModulesManager`
    public static let ID = "roster";
    
    public let logger = Logger(subsystem: "TigaseSwift", category: "RosterModule");
    
    public let criteria = Criteria.name("iq").add(Criteria.name("query", xmlns: "jabber:iq:roster"));
    
    open override var context: Context? {
        didSet {
            oldValue?.unregister(lifecycleAware: rosterManager);
            context?.register(lifecycleAware: rosterManager);
            store(context?.module(.streamFeatures).$streamFeatures.map({ $0.contains(.rosterVersioning) }).assign(to: \.isRosterVersioningAvailable, on: self));
        }
    }
    
    public let features = [String]();

    public let rosterManager: RosterManager;
    
    private let eventsSender = PassthroughSubject<RosterItemAction,Never>();
    public let events: AnyPublisher<RosterItemAction,Never>;
    
    public enum RosterItemAction {
        case addedOrUpdated(RosterItemProtocol)
        case removed(JID)
    }
    
    public private(set) var isRosterVersioningAvailable: Bool = false;
    
    public init(rosterManager: RosterManager) {
        self.rosterManager = rosterManager;
        self.events = eventsSender.eraseToAnyPublisher();
        super.init();
    }
    
    public override func stateChanged(newState: XMPPClient.State) {
        guard case .connected(let resumed) = newState, !resumed else {
            return;
        }
        self.requestRoster();
    }
        
    open func processGet(stanza: Stanza) throws {
        throw XMPPError.feature_not_implemented;
    }
    
    open func processSet(stanza: Stanza) throws {
        let bindedJid = context?.boundJid;
        if (stanza.from != nil && stanza.from != bindedJid && (stanza.from?.bareJid != bindedJid?.bareJid)) {
            throw XMPPError.not_allowed("You are not allowed to send this to me!");
        }
        
        if let query = stanza.findChild(name: "query", xmlns: "jabber:iq:roster"), let context = self.context {
            for item in query.getChildren(name: "item") {
                _ = self.processRosterItem(item, context: context);
            }
            
            rosterManager.set(version: query.getAttribute("ver"), for: context);
        }
    }
    
    private func processRosterItem(_ item:Element, context: Context) -> JID? {
        guard let jid = JID(item.getAttribute("jid")) else {
            return nil;
        }
        let name = item.getAttribute("name");
        let subscription: RosterItemSubscription = item.getAttribute("subscription") == nil ? .none : RosterItemSubscription(rawValue: item.getAttribute("subscription")!)!;
        let ask = item.getAttribute("ask") == "subscribe";
        let groups:[String] = item.mapChildren(transform: {(g:Element) -> String in
                return g.value!;
            }, filter: {(e:Element) -> Bool in
                return e.name == "group" && e.value != nil;
            });
        
        let annotations: [RosterItemAnnotation] = processRosterItemForAnnotations(item: item);

        if subscription == .remove {
            if let item = rosterManager.deleteItem(for: context, jid: jid) {
                eventsSender.send(.removed(jid));
                fire(ItemUpdatedEvent(context: context, rosterItem: item, action: .removed));
            }
            return jid;
        } else {
            let item = rosterManager.updateItem(for: context, jid: jid, name: name, subscription: subscription, groups: groups, ask: ask, annotations: annotations);
            eventsSender.send(.addedOrUpdated(item));
            fire(ItemUpdatedEvent(context: context, rosterItem: item, action: .added));
            return jid;
        }
    }
    
    fileprivate func processRosterItemForAnnotations(item: Element) -> [RosterItemAnnotation] {
        return context?.modulesManager.modules.map({ (module) -> RosterItemAnnotation? in
            if let aware = (module as? RosterAnnotationAwareProtocol) {
                return aware.process(rosterItemElem: item);
            } else {
                return nil;
            }
        }).filter({ $0 != nil}).map({ $0! }) ?? [];
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
        
        for module in context?.modulesManager.modules ?? [] {
            (module as? RosterAnnotationAwareProtocol)?.prepareRosterGetRequest(queryElem: query);
        }
        
        if isRosterVersioningAvailable, let context = self.context {
            let x = rosterManager.version(for: context) ?? "";
            query.setAttribute("ver", value: x);
        }
        iq.addChild(query);
        
        write(iq, completionHandler: { result in
            switch result {
            case .success(let iq):
                if let query = iq.findChild(name: "query", xmlns: "jabber:iq:roster"), let context = self.context {
                    let oldJids = self.rosterManager.items(for: context).map({ $0.jid });
                    let newJids: Set<JID> = Set(query.getChildren(name: "item").compactMap({ item in
                        return self.processRosterItem(item, context: context);
                    }));
                    
                    let removed = oldJids.filter({ !newJids.contains($0) });
                    for jid in removed {
                        if let item = self.rosterManager.deleteItem(for: context, jid: jid) {
                            self.eventsSender.send(.removed(jid));
                            self.fire(ItemUpdatedEvent(context: context, rosterItem: item, action: .removed));
                        }
                    }
                    
                    self.rosterManager.set(version: query.getAttribute("ver"), for: context);
                }
            default:
                break;
            }
            completionHandler?(result.map({ _ in Void() }));
        })
    }
    
    public func addItem(jid: JID, name: String?, groups:[String], completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
        self.updateItem(jid: jid, name: name, groups: groups, completionHandler: completionHandler);
    }
    
    public func updateItem(jid: JID, name: String?, groups:[String], completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
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

        query.addChild(item);
        
        write(iq, completionHandler: completionHandler);
    }

    public func removeItem(jid: JID, completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
        let iq = Iq();
        iq.type = .set;
        
        let query = Element(name:"query", xmlns:"jabber:iq:roster");
        iq.addChild(query);
        
        let item = Element(name: "item");
        item.setAttribute("jid", value: jid.stringValue);
        item.setAttribute("subscription", value: "remove");

        query.addChild(item);
        
        write(iq, completionHandler: completionHandler);
    }
            
    /**
     Actions which could happen to roster items:
     - added: item was added
     - removed: item was removed
     */
    public enum Action {
        case added // or updated
        case removed
    }

    /// Event fired when roster item is updated
    @available(*, deprecated, message: "Use RosterModule.events")
    open class ItemUpdatedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = ItemUpdatedEvent();
        
        /// Changed roster item
        public let rosterItem:RosterItemProtocol!;
        /// Action done to roster item
        public let action:Action!;
        
        fileprivate init() {
            self.rosterItem = nil;
            self.action = nil;
            super.init(type: "ItemUpdatedEvent");
        }
        
        public init(context: Context, rosterItem: RosterItemProtocol, action: Action) {
            self.rosterItem = rosterItem;
            self.action = action;
            super.init(type: "ItemUpdatedEvent", context: context);
        }
    }
    
}

protocol RosterAnnotationAwareProtocol {
    
    func prepareRosterGetRequest(queryElem el: Element);
    
    func process(rosterItemElem el: Element) -> RosterItemAnnotation?;
    
}
