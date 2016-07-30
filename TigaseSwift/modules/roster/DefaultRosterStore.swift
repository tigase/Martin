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
public class DefaultRosterStore: RosterStore {
 
    private var roster = [JID: RosterItem]();
    
    private var queue = dispatch_queue_create("roster_store_queue", DISPATCH_QUEUE_CONCURRENT);
    
    public override var count:Int {
        get {
            var result = 0;
            dispatch_sync(queue) {
                result = self.roster.count;
            }
            return result;
        }
    }
            
    public override func addItem(item:RosterItem) {
        dispatch_barrier_async(queue) {
            self.roster[item.jid] = item;
        }
    }
    
    public override func get(jid:JID) -> RosterItem? {
        var item: RosterItem?;
        dispatch_sync(queue) {
            item = self.roster[jid];
        }
        return item;
    }
    
    public override func removeItem(jid:JID) {
        dispatch_barrier_async(queue) {
            self.roster.removeValueForKey(jid);
        }
    }
    
    
}