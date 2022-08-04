//
// PresenceStore.swift
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
import Combine

public protocol PresenceStore {
    
    var bestPresenceEvents: PassthroughSubject<BestPresenceEvent,Never> { get };
    
    func reset(scopes: Set<ResetableScope>, for context: Context);
    
    func update(presence: Presence, for context: Context) -> Presence?;
    
    func removePresence(for jid: JID, context: Context) -> Bool;
    
    func presence(for jid: JID, context: Context) -> Presence?;
    
    func presences(for jid: BareJID, context: Context) -> [Presence];
    
    func bestPresence(for jid: BareJID, context: Context) -> Presence?;
    
}

public struct BestPresenceEvent {
    public let account: BareJID;
    public let jid: BareJID;
    public let presence: Presence?;
    
    public init(account: BareJID, jid: BareJID, presence: Presence?) {
        self.account = account;
        self.jid = jid;
        self.presence = presence;
    }
}
