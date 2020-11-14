//
// RoomManagerBase.swift
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

open class BaseRoomManagerBase<Room: RoomProtocol> {
    
    init() {
    }
    
    func cast(_ channel: RoomProtocol) -> Room {
        return channel as! Room;
    }
    
}

open class RoomManagerBase<Store: RoomStore>: BaseRoomManagerBase<Store.Room>, RoomManager {

    public let store: Store;
        
    public init(store: Store) {
        self.store = store;
    }
    
    public func rooms(for context: Context) -> [RoomProtocol] {
        return store.rooms(for: context);
    }
    
    open func room(for context: Context, with jid: BareJID) -> RoomProtocol? {
        return store.room(for: context, with: jid);
    }
    
    open func createRoom(for context: Context, with jid: BareJID, nickname: String, password: String?) -> RoomProtocol? {
        switch store.createRoom(for: context, with: jid, nickname: nickname, password: password) {
        case .created(let room):
            return room;
        case .found(let room):
            return room;
        case .none:
            return nil;
        }
    }
    
    /**
     Remove room instance
     - parameter room: room instance to remove
     */
    open func close(room: RoomProtocol) -> Bool {
        return store.close(room: cast(room));
    }
    
    open func initialize(context: Context) {
        store.initialize(context: context);
    }
    
    open func deinitialize(context: Context) {
        store.deinitialize(context: context);
    }
}
