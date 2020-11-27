//
// RoomOccupantsStoreBase.swift
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

open class RoomOccupantsStoreBase: RoomOccupantsStoreProtocol {
    
    private var presences: [String: MucOccupant] = [:];
    private var tempOccupants: [String: MucOccupant] = [:]
    
    public init() {
        
    }
    
    public var occupants: [MucOccupant] {
        return Array(presences.values);
    }
    
    public func occupant(nickname: String) -> MucOccupant? {
        return presences[nickname];
    }
    
    public func add(occupant: MucOccupant) {
        self.presences[occupant.nickname] = occupant;
    }
    
    public func remove(occupant: MucOccupant) {
        self.presences.removeValue(forKey: occupant.nickname);
    }
    
    public func addTemp(nickname: String, occupant: MucOccupant) {
        self.tempOccupants[nickname] = occupant;
    }
    
    public func removeTemp(nickname: String) -> MucOccupant? {
        return self.tempOccupants.removeValue(forKey: nickname);
    }
    
}
