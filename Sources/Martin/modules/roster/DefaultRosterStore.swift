//
// DefaultRosterStore.swift
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
 Class implements in-memory roster store
 
 For more informations see `RosterStore`
 */
open class DefaultRosterStore: RosterStore {
 
    public typealias RosterItem = RosterItemBase
    
    private var roster = [JID: RosterItem]();
    private var version: String?;
    
    private let dispatcher = DispatchQueue(label: "DefaultRoomStore");

    public init() {}

    public func clear(for context: Context) {
        return dispatcher.async {
            self.version = nil;
            self.roster.removeAll();
        }
    }
    
    public func items(for context: Context) -> [RosterItemBase] {
        return dispatcher.sync {
            return Array(roster.values);
        }
    }
    
    public func item(for context: Context, jid: JID) -> RosterItemBase? {
        return dispatcher.sync {
            return roster[jid];
        }
    }
    
    public func updateItem(for context: Context, jid: JID, name: String?, subscription: RosterItemSubscription, groups: [String], ask: Bool, annotations: [RosterItemAnnotation]) {
        let item = RosterItemBase(jid: jid, name: name, subscription: subscription, groups: groups, ask: ask, annotations: annotations);
        dispatcher.async {
            self.roster[jid] = item;
        }
    }
    
    public func deleteItem(for context: Context, jid: JID) {
        dispatcher.async {
            self.roster.removeValue(forKey: jid);
        }
    }
    
    public func version(for context: Context) -> String? {
        return dispatcher.sync {
            return self.version;
        }
    }
    
    public func set(version: String?, for context: Context) {
        dispatcher.async {
            self.version = version;
        }
    }
    
    public func initialize(context: Context) {
        
    }
    
    public func deinitialize(context: Context) {
        
    }
}
