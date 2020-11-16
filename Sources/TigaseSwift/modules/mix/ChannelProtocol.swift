//
// ChannelProtocol.swift
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

public protocol ChannelProtocol: ConversationProtocol {
 
    var nickname: String? { get }
    var state: ChannelState { get }
    var participantId: String { get }
    
    var permissions: Set<ChannelPermission>? { get }
    var participants: MixParticipantsProtocol { get }
    
    func update(state: ChannelState) -> Bool;
    func update(permissions: Set<ChannelPermission>)
}

extension ChannelProtocol {
    
    public func has(permission: ChannelPermission) -> Bool {
        return permissions?.contains(permission) ?? false;
    }
    
}

public enum ChannelState: Int {
    case left = 0
    case joined = 1
}

public enum ChannelPermission {
    case changeConfig
    case changeInfo
    case changeAvatar
}
