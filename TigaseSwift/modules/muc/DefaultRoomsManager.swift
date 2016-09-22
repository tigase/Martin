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
    
    open var context: Context! {
        didSet {
            for room in rooms.values {
                room.context = context;
            }
        }
    }
    
    fileprivate var rooms = [BareJID:Room]();
    
    fileprivate let queue = DispatchQueue(label: "room_manager_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    public init() {
        
    }
    
    /**
     Check if room is open
     - parameter roomJid: jid of room
     */
    open func contains(roomJid: BareJID) -> Bool {
        var result = false;
        queue.sync {
            result = self.rooms[roomJid] != nil;
        }
        return result;
    }
    
    /**
     Create instance of room
     - parameter roomJid: jid of room
     - parameter nickname: nickname
     - parameter password: password for room
     */
    open func createRoomInstance(roomJid: BareJID, nickname: String, password: String?) -> Room {
        let room = Room(context: context, roomJid: roomJid, nickname: nickname);
        room.password = password;
        return room;
    }
    
    /**
     Get room instance for room jid
     - parameter roomJid: jid of room
     - returns: instance of Room if created
     */
    open func getRoom(for roomJid: BareJID) -> Room? {
        var result: Room?;
        queue.sync {
            result = self.rooms[roomJid];
        }
        return result;
    }
    
    /**
     Get array of all open rooms
     - returns: array of rooms
     */
    open func getRooms() -> [Room] {
        var rooms: [Room]!;
        queue.sync {
            rooms = Array(self.rooms.values);
        }
        return rooms;
    }
    
    open func initialize() {
        
    }
    
    /**
     Register room instance in RoomManager
     - parameter room: room instance to register
     */
    open func register(room: Room) {
        queue.async(flags: .barrier, execute: {
            self.rooms[room.roomJid]  = room;
        }) 
    }
    
    /**
     Remove room instance
     - parameter room: room instance to remove
     */
    open func remove(room: Room) {
        queue.async(flags: .barrier, execute: {
            self.rooms.removeValue(forKey: room.roomJid);
        }) 
    }
}
