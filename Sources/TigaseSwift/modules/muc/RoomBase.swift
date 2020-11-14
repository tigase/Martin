//
// RoomBase.swift
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

open class RoomBase: ConversationBase, RoomProtocol {
    
    private var _state: RoomState = .not_joined;
    public var state: RoomState {
        get {
            return dispatcher.sync {
                return _state;
            }
        }
        set {
            dispatcher.async(flags: .barrier) {
                self._state = newValue;
            }
        }
    }
    public let nickname: String;
    public let password: String?;
    
    private let occupants = RoomOccupantsStoreBase();
    private let dispatcher: QueueDispatcher;
    
    private var _lastMessageDate: Date? = nil;
    public var lastMessageDate: Date? {
        get {
            return dispatcher.sync {
                return _lastMessageDate;
            }
        }
        set {
            dispatcher.async(flags: .barrier) {
                self._lastMessageDate = newValue;
            }
        }
    }
    
    public init(context: Context, jid: BareJID, nickname: String, password: String?, dispatcher: QueueDispatcher) {
        self.nickname = nickname;
        self.password = password;
        self.dispatcher = dispatcher;
        super.init(context: context, jid: JID(jid));
    }
    
    public func occupant(nickname: String) -> MucOccupant? {
        return dispatcher.sync {
            return occupants.occupant(nickname: nickname);
        }
    }
    
    public func add(occupant: MucOccupant) {
        dispatcher.async(flags: .barrier) {
            self.occupants.add(occupant: occupant);
        }
    }
    
    public func remove(occupant: MucOccupant) {
        dispatcher.async(flags: .barrier) {
            self.occupants.remove(occupant: occupant);
        }
    }
    
    public func addTemp(nickname: String, occupant: MucOccupant) {
        dispatcher.async(flags: .barrier) {
            self.occupants.addTemp(nickname: nickname, occupant: occupant);
        }
    }
    
    public func removeTemp(nickname: String) -> MucOccupant? {
        return dispatcher.sync(flags: .barrier) {
            return occupants.removeTemp(nickname: nickname);
        }
    }
}
