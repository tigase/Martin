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
 
    fileprivate var roster = [JID: RosterItem]();
    
    fileprivate var queue = DispatchQueue(label: "roster_store_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    open override var count:Int {
        get {
            var result = 0;
            queue.sync {
                result = self.roster.count;
            }
            return result;
        }
    }
            
    open override func addItem(_ item:RosterItem) {
        queue.async(flags: .barrier, execute: {
            self.roster[item.jid] = item;
        }) 
    }
    
    open func getJids() -> [JID] {
        var result = [JID]();
        queue.sync {
            self.roster.keys.forEach({ (jid) in
                result.append(jid);
            });
        }
        return result;
    }
    
    open override func get(for jid:JID) -> RosterItem? {
        var item: RosterItem?;
        queue.sync {
            item = self.roster[jid];
        }
        return item;
    }
    
    open override func removeItem(for jid:JID) {
        queue.async(flags: .barrier, execute: {
            self.roster.removeValue(forKey: jid);
        }) 
    }
    
    open override func removeAll() {
        queue.async(flags: .barrier) {
            self.roster.removeAll();
        }
    }
    
}
