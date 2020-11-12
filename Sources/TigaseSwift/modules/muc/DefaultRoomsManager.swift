//
// DefaultRoomsManager.swift
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
 Default MUC room manager for local handling of rooms
 */
open class DefaultRoomsManager: ContextAware {
    
    open weak var context: Context? {
        didSet {
            for room in rooms.values {
                room.context = context;
            }
        }
    }
    
    fileprivate var rooms = [BareJID:Room]();
    
    public let store: RoomStore;
        
    public init(store: RoomStore) {
        self.store = store;
    }
    
    /**
     Check if room is open
     - parameter roomJid: jid of room
     */
    open func contains(roomJid: BareJID) -> Bool {
        return store.room(for: roomJid) != nil;
    }
    
    /**
     Get room instance for room jid
     - parameter roomJid: jid of room
     - returns: instance of Room if created
     */
    open func getRoom(for roomJid: BareJID) -> Room? {
        return store.room(for: roomJid);
    }
    
    /**
     Get room instance for room jid or create a new one
     - parameter roomJid: jid of room
     - returns: instance of Room if created
     */
    open func getRoomOrCreate(for roomJid: BareJID, nickname: String, password: String?, onCreate: @escaping (Room)->Void) -> Result<Room,ErrorCondition> {
        return store.dispatcher.sync {
            if let room = store.room(for: roomJid) {
                return .success(room);
            }
            let result = store.createRoom(roomJid: roomJid, nickname: nickname, password: password);
            switch result {
            case .success(let room):
                DispatchQueue.global().async {
                    onCreate(room);
                }
            default:
                break
            }
            return result;
        }
    }

    
    /**
     Get array of all open rooms
     - returns: array of rooms
     */
    open func getRooms() -> [Room] {
        return store.rooms;
    }
            
    /**
     Remove room instance
     - parameter room: room instance to remove
     */
    open func close(room: Room) {
        _ = store.close(room: room);
    }
}
