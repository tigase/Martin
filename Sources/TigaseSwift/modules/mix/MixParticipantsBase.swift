//
// MixParticipantsBase.swift
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

public class MixParticipantsBase: MixParticipantsProtocol {
    
    @Published
    private var items: [String: MixParticipant] = [:]
    
    public var participants: [MixParticipant] {
        return Array(items.values);
    }
    
    public var participantsPublisher: AnyPublisher<[MixParticipant],Never> {
        return $items.map({ Array($0.values) }).eraseToAnyPublisher();
    }
    
    public init() {}
    
    public var count: Int {
        return participants.count;
    }
            
    public func participant(withId id: String) -> MixParticipant? {
        return items[id];
    }
    
    public func set(participants: [MixParticipant]) {
        self.items = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) });
    }
    
    public func update(participant: MixParticipant) {
        self.items[participant.id] = participant;
    }
    
    public func removeParticipant(withId id: String) -> MixParticipant? {
        self.items.removeValue(forKey: id);
    }
}
