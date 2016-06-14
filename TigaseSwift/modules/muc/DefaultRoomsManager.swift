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
public class DefaultRoomsManager: ContextAware {
    
    public var context: Context! {
        didSet {
            for room in rooms.values {
                room.context = context;
            }
        }
    }
    
    private var rooms = [BareJID:Room]();
    
    public init() {
        
    }
    
    /**
     Check if room is open
     - parameter roomJid: jid of room
     */
    public func contains(roomJid: BareJID) -> Bool {
        return rooms[roomJid] != nil;
    }
    
    /**
     Create instance of room
     - parameter roomJid: jid of room
     - parameter nickname: nickname
     - parameter password: password for room
     */
    public func createRoomInstance(roomJid: BareJID, nickname: String, password: String?) -> Room {
        let room = Room(context: context, roomJid: roomJid, nickname: nickname);
        room.password = password;
        return room;
    }
    
    /**
     Get room instance for room jid
     - parameter roomJid: jid of room
     - returns: instance of Room if created
     */
    public func get(roomJid: BareJID) -> Room? {
        return rooms[roomJid];
    }
    
    /**
     Get array of all open rooms
     - returns: array of rooms
     */
    public func getRooms() -> [Room] {
        return Array(rooms.values);
    }
    
    public func initialize() {
        
    }
    
    /**
     Register room instance in RoomManager
     - parameter room: room instance to register
     */
    public func register(room: Room) {
        rooms[room.roomJid]  = room;
    }
    
    /**
     Remove room instance
     - parameter room: room instance to remove
     */
    public func remove(room: Room) {
        rooms.removeValueForKey(room.roomJid);
    }
}