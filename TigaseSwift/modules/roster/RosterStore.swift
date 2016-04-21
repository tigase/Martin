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

public class RosterStore {
    
    public var count:Int {
        get {
            return -1;
        }
    }
    
    public var handler:RosterStoreHandler?;
        
    public func add(jid:JID, name:String?, groups:[String] = [String](), onSuccess:(stanza:Stanza) -> Void, onError:(errorCondition:ErrorCondition?) -> Void) {
        handler?.add(jid, name: name, groups: groups, onSuccess: onSuccess, onError: onError);
    }
    
    public func cleared() {
        removeAll();
        handler?.cleared();
    }

    public func remove(jid:JID, onSuccess:(stanza:Stanza) -> Void, onError:(errorCondition:ErrorCondition?) -> Void) {
        handler?.remove(jid, onSuccess: onSuccess, onError: onError);
    }

    public func update(rosterItem:RosterItem, onSuccess:(stanza:Stanza) -> Void, onError:(errorCondition:ErrorCondition?) -> Void) {
        handler?.update(rosterItem, onSuccess: onSuccess, onError: onError);
    }
    
    public func addItem(item:RosterItem) {
    }
    
    public func get(jid:JID) -> RosterItem? {
        return nil;
    }
    
    public func removeAll() {
    }
    
    public func removeItem(jid:JID) {
    }
    
}

public protocol RosterStoreHandler {

    func add(jid:JID, name:String?, groups:[String], onSuccess:(stanza:Stanza) -> Void, onError:(errorCondition:ErrorCondition?) -> Void);
    func cleared();
    func remove(jid:JID, onSuccess:(stanza:Stanza) -> Void, onError:(errorCondition:ErrorCondition?) -> Void);
    func update(rosterItem:RosterItem, onSuccess:(stanza:Stanza) -> Void, onError:(errorCondition:ErrorCondition?) -> Void);
    
}