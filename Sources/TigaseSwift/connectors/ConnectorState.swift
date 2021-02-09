//
// ConnectorState.swift
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

/**
 Possible states of connection:
 - connecting: Trying to establish connection to XMPP server
 - connected: Connection to XMPP server is established
 - disconnecting: Connection to XMPP server is being closed
 - disconnected: Connection to XMPP server is closed
 */
public enum ConnectorState: Equatable {
    
    public static func == (lhs: ConnectorState, rhs: ConnectorState) -> Bool {
        return lhs.value == rhs.value;
    }
    
    case connecting
    case connected
    case disconnecting
    case disconnected(DisconnectionReason = .none)
    
    private var value: Int {
        switch self {
        case .disconnected(_):
            return 0;
        case .connecting:
            return 1;
        case .connected:
            return 2;
        case .disconnecting:
            return 3;
        }
    }
    
    public enum DisconnectionReason {
        case none
        case timeout
        case sslCertError(SecTrust)
        case xmlError(String?)
        case streamError(Element)
    }
}
