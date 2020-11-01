//
// BlockingCommandModule.swift
//
// TigaseSwift
// Copyright (C) 2019 "Tigase, Inc." <office@tigase.com>
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

open class BlockingCommandModule: XmppModule, ContextAware, EventHandler {
    
    public static let BC_XMLNS = "urn:xmpp:blocking";
    /// ID of module to lookup for in `XmppModulesManager`
    public static let ID = BC_XMLNS;
    
    public let id = BC_XMLNS;
    
    public let criteria = Criteria.name("iq", types: [.set]).add(Criteria.or(Criteria.name("block", xmlns: BlockingCommandModule.BC_XMLNS), Criteria.name("unblock", xmlns: BlockingCommandModule.BC_XMLNS)));
    
    public let features = [String]();
    
    open var context:Context! {
        didSet {
            if context != nil {
                context.eventBus.register(handler: self, for: [StreamManagementModule.FailedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE, DiscoveryModule.ServerFeaturesReceivedEvent.TYPE]);
            } else if oldValue != nil {
                oldValue.eventBus.unregister(handler: self, for: [StreamManagementModule.FailedEvent.TYPE, SocketConnector.DisconnectedEvent.TYPE, DiscoveryModule.ServerFeaturesReceivedEvent.TYPE]);
            }
        }
    }
    
    open var isAvailable: Bool {
        if let features: [String] = context.sessionObject.getProperty(DiscoveryModule.SERVER_FEATURES_KEY) {
            if features.contains(BlockingCommandModule.BC_XMLNS) {
                return true;
            }
        }
        
        return false;
    }
    
    open fileprivate(set) var blockedJids: [JID]? {
        didSet {
            let added = (blockedJids ?? []).filter({ !(oldValue?.contains($0) ?? false) });
            let removed = (oldValue ?? []).filter({ !(blockedJids?.contains($0) ?? false) });
            context.eventBus.fire(BlockedChangedEvent(sessionObject: context.sessionObject, blocked: blockedJids ?? [], added: added, removed: removed));
        }
    }
    
    open var automaticallyRetrieve: Bool = true;
    
    public init() {
    }
        
    public func handle(event: Event) {
        switch event {
        case let e as SocketConnector.DisconnectedEvent:
            if e.clean {
                blockedJids = nil;
            }
        case _ as StreamManagementModule.FailedEvent:
            blockedJids = nil;
        case let e as DiscoveryModule.ServerFeaturesReceivedEvent:
            if e.features.contains(BlockingCommandModule.BC_XMLNS) {
                self.retrieveBlockedJids(completionHandler: nil);
            }
        default:
            break;
        }
    }
    
    open func process(stanza: Stanza) throws {
        guard let actionEl = stanza.findChild(xmlns: BlockingCommandModule.BC_XMLNS) else {
            throw ErrorCondition.feature_not_implemented;
        }
        
        switch actionEl.name {
        case "block":
            if var blocked = self.blockedJids {
                let newJids = actionEl.mapChildren(transform: { JID($0.getAttribute("jid")) }, filter: { $0.name == "item" }).filter({ jid in !blocked.contains(jid) });
                guard !newJids.isEmpty else {
                    return;
                }
                blocked.append(contentsOf: newJids);
                self.blockedJids = blocked;
            }
        case "unblock":
            if let blocked = self.blockedJids {
                let newJids = actionEl.mapChildren(transform: { JID($0.getAttribute("jid")) }, filter: { $0.name == "item" }).filter({ jid in blocked.contains(jid) });
                guard !newJids.isEmpty else {
                    return;
                }
                self.blockedJids = blocked.filter({ jid in !newJids.contains(jid)});
            }
        default:
            throw ErrorCondition.feature_not_implemented;
        }
    }
    
    /**
     Block communication with jid
     - paramater jid: jid to block
     */
    open func block(jids: [JID], completionHandler: @escaping (Result<Void,ErrorCondition>)->Void) {
        guard !jids.isEmpty else {
            completionHandler(.success(Void()));
            return;
        }
        
        let iq = Iq();
        iq.type = StanzaType.set;
        let block = Element(name: "block", xmlns: BlockingCommandModule.BC_XMLNS, children: jids.map({ jid in Element(name: "item", attributes: ["jid": jid.stringValue])}));
        iq.addChild(block);
        context.writer?.write(iq, callback: { result in
            if (result?.type ?? .error) == .error {
                completionHandler(.failure(result?.errorCondition ?? ErrorCondition.remote_server_timeout));
            } else {
                completionHandler(.success(Void()));
            }
        })
    }
    
    /**
     Unblock communication with jid
     - paramater jid: to unblock
     */
    open func unblock(jids: [JID], completionHandler: @escaping (Result<Void,ErrorCondition>)->Void) {
        guard !jids.isEmpty else {
            completionHandler(.success(Void()));
            return;
        }
        
        let iq = Iq();
        iq.type = StanzaType.set;
        let unblock = Element(name: "unblock", xmlns: BlockingCommandModule.BC_XMLNS, children: jids.map({ jid in Element(name: "item", attributes: ["jid": jid.stringValue])}));
        iq.addChild(unblock);
        context.writer?.write(iq, callback: { result in
            if (result?.type ?? .error) == .error {
                completionHandler(.failure(result?.errorCondition ?? ErrorCondition.remote_server_timeout));
            } else {
                completionHandler(.success(Void()));
            }
        })
    }
    
    open func retrieveBlockedJids(completionHandler: ((Result<[JID],ErrorCondition>)->Void)?) {
        guard let blockedJids = self.blockedJids else {
            let iq = Iq();
            iq.type = StanzaType.get;
            let list = Element(name: "blocklist", xmlns: BlockingCommandModule.BC_XMLNS);
            iq.addChild(list);

            context.writer?.write(iq, callback: { result in
                if (result?.type ?? .error) == .error {
                    completionHandler?(.failure(result?.errorCondition ?? ErrorCondition.remote_server_timeout));
                } else {
                    let blockedJids = result!.findChild(name: "blocklist", xmlns: BlockingCommandModule.BC_XMLNS)?.mapChildren(transform: { (el) -> JID? in
                    return JID(el.getAttribute("jid"));
                    }) ?? [];
                    self.blockedJids = blockedJids;
                    completionHandler?(.success(blockedJids));
                }
            })
            return;
        }
        completionHandler?(.success(blockedJids));
    }
 
    open class BlockedChangedEvent: Event {
         /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = BlockedChangedEvent();
               
        public let type = "BlockingCommandBlockChangedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        
        /// List of blocked JIDs
        public let blocked: [JID];
        public let added: [JID];
        public let removed: [JID];
        
        fileprivate init() {
            self.sessionObject = nil;
            self.blocked = [];
            self.added = [];
            self.removed = [];
        }
        
        public init(sessionObject: SessionObject, blocked: [JID], added: [JID], removed: [JID]) {
            self.sessionObject = sessionObject;
            self.blocked = blocked;
            self.added = added;
            self.removed = removed;
        }
    }
}

