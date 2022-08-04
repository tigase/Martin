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
import Combine

open class RoomBase: ConversationBase, RoomProtocol, @unchecked Sendable {
    
    open override var defaultMessageType: StanzaType {
        return .groupchat;
    }

    @Published
    public var state: RoomState = .not_joined();
    public var statePublisher: AnyPublisher<RoomState, Never> {
        return $state.eraseToAnyPublisher();
    }
    
    public let nickname: String;
    public let password: String?;
    
    private let occupantsStore = RoomOccupantsStoreBase();
    public var occupantsPublisher: AnyPublisher<[MucOccupant], Never> {
        return occupantsStore.occupantsPublisher;
    }
    
    private let queue: DispatchQueue;
    
    public var affiliation: MucAffiliation = .none;
    public var role: MucRole = .none;
    
    public init(context: Context, jid: BareJID, nickname: String, password: String?, queue: DispatchQueue) {
        self.nickname = nickname;
        self.password = password;
        self.queue = queue;
        super.init(context: context, jid: jid);
    }
    
    public var occupants: [MucOccupant] {
        return queue.sync {
            return self.occupantsStore.occupants;
        }
    }
    
    public func occupant(nickname: String) -> MucOccupant? {
        return queue.sync {
            return occupantsStore.occupant(nickname: nickname);
        }
    }
    
    public func addOccupant(nickname: String, presence: Presence) -> MucOccupant {
        let occupant = MucOccupant(nickname: nickname, presence: presence, for: self);
        queue.async(flags: .barrier) {
            self.occupantsStore.add(occupant: occupant);
        }
        return occupant;
    }
    
    public func remove(occupant: MucOccupant) {
        queue.async(flags: .barrier) {
            self.occupantsStore.remove(occupant: occupant);
        }
    }
    
    public func addTemp(nickname: String, occupant: MucOccupant) {
        queue.async(flags: .barrier) {
            self.occupantsStore.addTemp(nickname: nickname, occupant: occupant);
        }
    }
    
    public func removeTemp(nickname: String) -> MucOccupant? {
        return queue.sync(flags: .barrier) {
            return occupantsStore.removeTemp(nickname: nickname);
        }
    }
    
    public func update(state: RoomState) {
        queue.async {
            self.state = state;
        }
    }
}
