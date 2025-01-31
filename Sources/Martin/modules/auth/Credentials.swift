//
// Credentials.swift
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
import CryptoKit
import Combine

public struct Credentials: Codable, Equatable, Sendable {

    public static func anonymous() -> Credentials {
        return Credentials();
    }
    
    public static func password(_ value: String) -> Credentials {
        return Credentials(password: value);
    }

    public var authenticationName: String?;
    public var password: String?;
    public var saltedPassword: SaltedPassword?;
    public var fastToken: FastMechanismToken?;
    
    public var isEmpty: Bool {
        return password == nil && saltedPassword == nil && fastToken == nil && authenticationName == nil;
    }
    
    public func test(_ predicate: (Credentials)->Bool) -> Bool {
        return predicate(self);
    }
}

public struct SaltedPassword: Codable, Equatable, Sendable {
    
    public let id: String;
    public let data: Data;
    
    public init(id: String, data: Data) {
        self.id = id;
        self.data = data
    }
    
    public static func generateId(mechanismName: String, salt: Data, iterations: Int) -> String {
        return Insecure.SHA1.hash(toHex: mechanismName.data(using: .utf8)! + String(iterations).data(using: .utf8)! + salt);
    }
}

extension FastMechanismToken: Codable, Equatable {
    
    public static func == (lhs: FastMechanismToken, rhs: FastMechanismToken) -> Bool {
        return lhs.mechanism == rhs.mechanism && lhs.value == rhs.value && lhs.expiresAt == rhs.expiresAt;
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self);
        mechanism = try container.decode(String.self, forKey: .mechinism);
        value = try container.decode(String.self, forKey: .value);
        expiresAt = try container.decode(Date.self, forKey: .expiresAt);
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self);
        try container.encode(mechanism, forKey: .mechinism);
        try container.encode(value, forKey: .value);
        try container.encode(expiresAt, forKey: .expiresAt);
    }
    
    enum CodingKeys: String, CodingKey {
        case mechinism
        case expiresAt
        case value
    }
}
