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
        Task {
            try await self.requestRoster();
        }
    }
        
    open func processGet(stanza: Stanza) throws {
        throw XMPPError(condition: .feature_not_implemented);
    }
    
    open func processSet(stanza: Stanza) throws {
        let bindedJid = context?.boundJid;
        if (stanza.from != nil && stanza.from != bindedJid && (stanza.from?.bareJid != bindedJid?.bareJid)) {
            throw XMPPError(condition: .not_allowed, message: "You are not allowed to send this to me!");
        }
        
        if let query = stanza.firstChild(name: "query", xmlns: "jabber:iq:roster"), let context = self.context {
            for item in query.filterChildren(name: "item") {
                _ = self.processRosterItem(item, context: context);
            }
            
            rosterManager.set(version: query.attribute("ver"), for: context);
        }
    }
    
    private func processRosterItem(_ item:Element, context: Context) -> JID? {
        guard let jid = JID(item.attribute("jid")) else {
            return nil;
        }
        let name = item.attribute("name");
        let subscription: RosterItemSubscription = RosterItemSubscription(item.attribute("subscription")) ?? .none;
        let ask = item.attribute("ask") == "subscribe";
        let groups:[String] = item.filterChildren(name: "group").compactMap({ $0.value });
        
        let annotations: [RosterItemAnnotation] = processRosterItemForAnnotations(item: item);

        if subscription == .remove {
            if rosterManager.deleteItem(for: context, jid: jid) != nil {
                eventsSender.send(.removed(jid));
            }
            return jid;
        } else {
            if let item = rosterManager.updateItem(for: context, jid: jid, name: name, subscription: subscription, groups: groups, ask: ask, annotations: annotations) {
                eventsSender.send(.addedOrUpdated(item));
            }
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
    open func requestRoster() async throws {
        let iq = Iq(type: .get, {
            Element(name:"query", xmlns:"jabber:iq:roster", {
                if isRosterVersioningAvailable, let context = self.context {
                    Attribute("ver", value: rosterManager.version(for: context) ?? "")
                }
                for module in (context?.modulesManager.modules ?? []).compactMap({ $0 as? RosterAnnotationAwareProtocol }) {
                    module.rosterExtensionRequestElement();
                }
            })
        });
        
        let response = try await write(iq: iq);
        if let query = response.firstChild(name: "query", xmlns: "jabber:iq:roster"), let context = self.context {
            let oldJids = self.rosterManager.items(for: context).map({ $0.jid });
            let newJids: Set<JID> = Set(query.filterChildren(name: "item").compactMap({ item in
                return self.processRosterItem(item, context: context);
            }));
        
            let removed = oldJids.filter({ !newJids.contains($0) });
            for jid in removed {
                if self.rosterManager.deleteItem(for: context, jid: jid) != nil {
                    self.eventsSender.send(.removed(jid));
                }
            }
        
            self.rosterManager.set(version: query.attribute("ver"), for: context);
        }
    }
    
    public func addItem(jid: JID, name: String?, groups:[String]) async throws -> Iq {
        return try await self.updateItem(jid: jid, name: name, groups: groups);
    }
    
    public func updateItem(jid: JID, name: String?, groups:[String]) async throws -> Iq {
        let iq = Iq(type: .set, {
            Element(name:"query", xmlns:"jabber:iq:roster", {
                Element(name: "item", {
                    Attribute("jid", value: jid.description)
                    if !(name?.isEmpty ?? true) {
                        Attribute("name", value: name)
                    }
                    for group in groups {
                        Element(name:"group", cdata:group)
                    }
                })
            })
        });
        
        return try await write(iq: iq);
    }
            
    public func removeItem(jid: JID) async throws -> Iq {
        let iq = Iq(type: .set, {
            Element(name:"query", xmlns:"jabber:iq:roster", {
                Attribute("jid", value: jid.description)
                Attribute("subscription", value: "remove")
            })
        });
        
        return try await write(iq: iq);
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
    
}

protocol RosterAnnotationAwareProtocol {
    
    func rosterExtensionRequestElement() -> Element?
    
    func process(rosterItemElem el: Element) -> RosterItemAnnotation?;
    
}

// async-await support
extension RosterModule {

    @available(*, deprecated, renamed: "requestRoster")
    open func rosterRequest() {
        requestRoster(completionHandler: nil)
    }

    open func requestRoster(completionHandler: ((Result<Void, XMPPError>)->Void)? = nil) {
        Task {
            do {
                try await requestRoster();
                completionHandler?(.success(Void()));
            } catch {
                completionHandler?(.failure(error as? XMPPError ?? .undefined_condition))
            }
        }
    }

    public func addItem(jid: JID, name: String?, groups:[String], completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        self.updateItem(jid: jid, name: name, groups: groups, completionHandler: completionHandler);
    }

    public func updateItem(jid: JID, name: String?, groups:[String], completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = .set;

        let query = Element(name:"query", xmlns:"jabber:iq:roster");
        iq.addChild(query);

        let item = Element(name: "item");
            item.attribute("jid", newValue: jid.description);
        if !(name?.isEmpty ?? true) {
            item.attribute("name", newValue: name);
        }
        groups.forEach({(group:String)->Void in
            item.addChild(Element(name:"group", cdata:group));
        });

        query.addChild(item);

        write(iq: iq, completionHandler: completionHandler);
    }

    public func removeItem(jid: JID, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        let iq = Iq();
        iq.type = .set;

        let query = Element(name:"query", xmlns:"jabber:iq:roster");
        iq.addChild(query);

        let item = Element(name: "item");
        item.attribute("jid", newValue: jid.description);
        item.attribute("subscription", newValue: "remove");

        query.addChild(item);

        write(iq: iq, completionHandler: completionHandler);
    }

}
