//
// ConnectorProtocol.swift
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

public struct ConnectorProtocol: RawRepresentable, Hashable {
    
    public let rawValue: String;
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue;
    }
    
    public init?(rawValue: String) {
        self.rawValue = rawValue;
    }
    
}

extension ConnectorProtocol {
    
    public static let XMPP = ConnectorProtocol("xmpp-client");
    public static let XMPPS = ConnectorProtocol("xmpps-client");

}
