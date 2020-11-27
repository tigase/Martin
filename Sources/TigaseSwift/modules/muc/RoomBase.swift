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
    
    open override var defaultMessageType: StanzaType {
        return .groupchat;
    }

    private var _state: RoomState = .not_joined;
    public var state: RoomState {
        get {
            return dispatcher.sync {
                return _state;
            }
        }
    }
    public let nickname: String;
    public let password: String?;
    
    private let occupantsStore = RoomOccupantsStoreBase();
    private let dispatcher: QueueDispatcher;
    
    public init(context: Context, jid: BareJID, nickname: String, password: String?, dispatcher: QueueDispatcher) {
        self.nickname = nickname;
        self.password = password;
        self.dispatcher = dispatcher;
        super.init(context: context, jid: jid);
    }
    
    public var occupants: [MucOccupant] {
        return dispatcher.sync {
            return self.occupantsStore.occupants;
        }
    }
    
    public func occupant(nickname: String) -> MucOccupant? {
        return dispatcher.sync {
            return occupantsStore.occupant(nickname: nickname);
        }
    }
    
    public func add(occupant: MucOccupant) {
        dispatcher.async(flags: .barrier) {
            self.occupantsStore.add(occupant: occupant);
        }
    }
    
    public func remove(occupant: MucOccupant) {
        dispatcher.async(flags: .barrier) {
            self.occupantsStore.remove(occupant: occupant);
        }
    }
    
    public func addTemp(nickname: String, occupant: MucOccupant) {
        dispatcher.async(flags: .barrier) {
            self.occupantsStore.addTemp(nickname: nickname, occupant: occupant);
        }
    }
    
    public func removeTemp(nickname: String) -> MucOccupant? {
        return dispatcher.sync(flags: .barrier) {
            return occupantsStore.removeTemp(nickname: nickname);
        }
    }
    
    public func update(state: RoomState) {
        dispatcher.async {
            self._state = state;
        }
    }
}
