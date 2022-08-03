//
// RosterManagerBase.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

open class RosterManagerBase<Store: RosterStore>: RosterManager {
    
    public let store: Store;
    
    public init(store: Store) {
        self.store = store;
    }
    
    public func clear(for context: Context) {
        store.clear(for: context);
    }
    
    public func items(for context: Context) -> [RosterItemProtocol] {
        return store.items(for: context);
    }
    
    public func item(for context: Context, jid: JID) -> RosterItemProtocol? {
        return store.item(for: context, jid: jid);
    }
    
    public func updateItem(for context: Context, jid: JID, name: String?, subscription: RosterItemSubscription, groups: [String], ask: Bool, annotations: [RosterItemAnnotation]) -> RosterItemProtocol? {
        store.updateItem(for: context, jid: jid, name: name, subscription: subscription, groups: groups, ask: ask, annotations: annotations);
        
        return store.item(for: context, jid: jid);
    }
    
    public func deleteItem(for context: Context, jid: JID) -> RosterItemProtocol? {
        if let item = store.item(for: context, jid: jid) {
            store.deleteItem(for: context, jid: jid);
            return item;
        } else {
            return nil;
        }
    }

    public func version(for context: Context) -> String? {
        return store.version(for: context);
    }
    
    public func set(version: String?, for context: Context) {
        store.set(version: version, for: context);
    }
    
    public func initialize(context: Context) {
        store.initialize(context: context);
    }
    
    public func deinitialize(context: Context) {
        store.deinitialize(context: context);
    }
}
