//
// MucOccupant.swift
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

/**
 Class is representation of MUC room occupant
 */
open class MucOccupant: Hashable {
    
    public static func ==(lhs: MucOccupant, rhs: MucOccupant) -> Bool {
        return lhs.nickname == rhs.nickname;
    }
    
    @Published
    public private(set) var presence: Presence;
    public let nickname: String;

    public var xUser: XMucUserElement? {
        return XMucUserElement.extract(from: presence);
    }
    public var affiliation: MucAffiliation {
        return xUser?.affiliation ?? .none;
    }
    public var role: MucRole {
        return xUser?.role ?? .none;
    }
    public var jid: JID? {
        return xUser?.jid;
    }
    
    public private(set) weak var room: RoomProtocol?;

    public init(nickname: String, presence: Presence, for room: RoomProtocol) {
        self.nickname = nickname;
        self.presence = presence;
        self.room = room;
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(nickname);
    }
    
    public func set(presence: Presence) {
        print("setting presence for \(nickname) to \(presence.show?.rawValue ?? "offline")");
        self.presence = presence;
    }
}

