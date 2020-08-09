//
// RosterStore.swift
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
 This is abstract class which as a base class for roster stores.
 It provides methods for modification of roster items.
 Modifications should be done using methods:
 ```
 add(..);
 remove(..);
 update(..);
 ```
 It will call `RosterModule` to execute change on server and 
 later will update local roster store.
 
 Do not use following methods directly - they will be called by
 `RosterModule` when confirmation will be received from server:
 ```
 addItem(..);
 removeAll(..);
 removeItem(..);
 ```
 */
open class RosterStore {
    
    /// Number of items in roster
    open var count:Int {
        get {
            return -1;
        }
    }
    
    /**
     Holds instace responsible for modification of roster
     on server side
     */
    open var handler:RosterStoreHandler?;
    
    public init() {
        
    }
    
    /**
     Add item to roster
     - parameter jid: jid
     - parameter name: name for item
     - parameter groups: groups to which item should belong
     - parameter onSuccess: called after item is added
     - parameter onError: called on failure
     */
    open func add(jid:JID, name:String?, groups:[String] = [String](), onSuccess:((_ stanza:Stanza) -> Void)?, onError:((_ errorCondition:ErrorCondition?) -> Void)?) {
        handler?.add(jid: jid, name: name, groups: groups, onSuccess: onSuccess, onError: onError);
    }
    
    open func cleared() {
        removeAll();
        handler?.cleared();
    }

    /**
     Remove item from roster
     - parameter jid: jid
     - parameter onSuccess: called after item is added
     - parameter onError: called on failure
     */
    open func remove(jid:JID, onSuccess:((_ stanza:Stanza) -> Void)?, onError:((_ errorCondition:ErrorCondition?) -> Void)?) {
        handler?.remove(jid: jid, onSuccess: onSuccess, onError: onError);
    }

    /**
     Update item in roster
     - parameter rosterItem: roster item to update
     - parameter name: name to change name of roster item to
     - parameter groups: list of groups name to which item should belong
     - parameter onSuccess: called after item is added
     - parameter onError: called on failure
     */
    open func update(item:RosterItem, name: String?, groups:[String]? = nil, onSuccess:((_ stanza:Stanza) -> Void)?, onError:((_ errorCondition:ErrorCondition?) -> Void)?) {
        handler?.update(item: item, name: name, groups: groups, onSuccess: onSuccess, onError: onError);
    }

    /**
     Update item in roster
     - parameter rosterItem: roster item to update
     - parameter groups: list of groups name to which item should belong
     - parameter onSuccess: called after item is added
     - parameter onError: called on failure
     */
    open func update(item:RosterItem, groups:[String], onSuccess:((_ stanza:Stanza) -> Void)?, onError:((_ errorCondition:ErrorCondition?) -> Void)?) {
        handler?.update(item: item, groups: groups, onSuccess: onSuccess, onError: onError);
    }
    
    open func addItem(_ item:RosterItem) {
    }

    open func getJids() -> [JID] {
        return [];
    }
    
    /**
     Retrieve roster item for JID
     - parameter jid: jid
     - returns: `RosterItem` for JID if exists
     */
    open func get(for jid:JID) -> RosterItem? {
        return nil;
    }
    
    open func removeAll() {
    }
    
    open func removeItem(for jid:JID) {
    }
    
}

/**
 Protocol implemented by classes responsible for making changes 
 to roster on server side
 */
public protocol RosterStoreHandler {

    func add(jid:JID, name:String?, groups:[String], onSuccess:((_ stanza:Stanza) -> Void)?, onError:((_ errorCondition:ErrorCondition?) -> Void)?);
    func cleared();
    func remove(jid:JID, onSuccess:((_ stanza:Stanza) -> Void)?, onError:((_ errorCondition:ErrorCondition?) -> Void)?);
    func update(item:RosterItem, name:String?, groups:[String]?, onSuccess:((_ stanza:Stanza) -> Void)?, onError:((_ errorCondition:ErrorCondition?) -> Void)?);
    func update(item:RosterItem, groups:[String], onSuccess:((_ stanza:Stanza) -> Void)?, onError:((_ errorCondition:ErrorCondition?) -> Void)?);
    
}
