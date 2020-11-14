//
// DefaultRoomStore.swift
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

open class DefaultRoomStore: RoomStore {
    
    public typealias Room = RoomBase

    private let dispatcher = QueueDispatcher(label: "DefaultRoomsStore");
    private var rooms = [BareJID: Room]();
    
    public func rooms(for context: Context) -> [RoomBase] {
        return dispatcher.sync {
            return rooms.values.compactMap({ $0 });
        }
    }
    
    public func room(for context: Context, with jid: BareJID) -> RoomBase? {
        return dispatcher.sync {
            return rooms[jid];
        }
    }
    
    public func createRoom(for context: Context, with jid: BareJID, nickname: String, password: String?) -> ConversationCreateResult<RoomBase> {
        return dispatcher.sync {
            guard let room = rooms[jid] else {
                let room = RoomBase(context: context, jid: jid, nickname: nickname, password: password, dispatcher: self.dispatcher);
                rooms[jid] = room;
                return .created(room);
            }
            return .found(room);
        }
    }
    
    public func close(room: RoomBase) -> Bool {
        return dispatcher.sync {
            return self.rooms.removeValue(forKey: room.jid.bareJid) != nil;
        }
    }

    public func initialize(context: Context) {
    }
    
    public func deinitialize(context: Context) {
    }
    
}
