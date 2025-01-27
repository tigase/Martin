//
// SeeOtherHost.swift
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

public struct SeeOtherHost: CustomStringConvertible {

    public static func from(location: String?) -> SeeOtherHost? {
        guard let location else {
            return nil;
        }
        guard location.last != "]" else {
            return .init(host: location, port: nil);
        }
        guard let idx = location.lastIndex(of: ":") else {
            return .init(host: location, port: nil);
        }
        return .init(host: String(location[location.startIndex..<idx]), port: Int(location[location.index(after: idx)..<location.endIndex]));
    }

    public let host: String;
    public let port: Int?;
    
    public var description: String {
        guard let port else {
            return host;
        }
        return "\(host):\(port)"
    }
    
    public init(host: String, port: Int? = nil) {
        self.host = host
        self.port = port
    }
    
}
