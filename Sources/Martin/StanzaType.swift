//
// StanzaType.swift
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

/// Enum contains possible types which may appear as type of XMPP stanza
public enum StanzaType: String, Sendable, CustomStringConvertible {
    
    public var description: String {
        return rawValue
    }
    
    // common
    case error
    // iq
    case get
    case set
    case result
    // message
    case chat
    case groupchat
    case headline
    case normal
    // presence subscription
    case subscribe
    case subscribed
    case unsubscribe
    case unsubscribed
    // presence state
    case probe
    case unavailable
    case available
}
