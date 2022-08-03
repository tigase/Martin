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
public protocol RosterStore: ContextLifecycleAware {
        
    associatedtype RosterItem: RosterItemProtocol
    
    func clear(for context: Context);

    func items(for context: Context) -> [RosterItem];
    
    func item(for context: Context, jid: JID) -> RosterItem?;
    
    func updateItem(for context: Context, jid: JID, name: String?, subscription: RosterItemSubscription, groups: [String], ask: Bool, annotations: [RosterItemAnnotation]);
    
    func deleteItem(for context: Context, jid: JID);
    
    func version(for context: Context) -> String?;
    
    func set(version: String?, for context: Context);
    
}
