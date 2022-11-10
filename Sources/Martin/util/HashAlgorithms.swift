//
// HashAlgorithms.swift
//
// TigaseSwift
// Copyright (C) 2022 "Tigase, Inc." <office@tigase.com>
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

public protocol HashAlgorithm {

    associatedtype Hash: HashFunction

    static var name: String { get }

    static func digest<D: DataProtocol>(data: D) -> Data;
    static func hmac<K: ContiguousBytes, D: DataProtocol>(key: K, data: D) -> Data;

}

extension HashAlgorithm {

    public static func digest<D: DataProtocol>(data: D) -> Data {
        return Data(Hash.hash(data: data));
    }

    public static func hmac<K: ContiguousBytes, D: DataProtocol>(key: K, data: D) -> Data {
        return Data(HMAC<Hash>.authenticationCode(for: data, using: .init(data: key)));
    }

}

public struct HashAlgorithms {
   
    public struct SHA1: HashAlgorithm {

        public typealias Hash = Insecure.SHA1;

        public static var name: String {
            return "SHA-1";
        }
        
    }
    
    public struct SHA256: HashAlgorithm {

        public typealias Hash = CryptoKit.SHA256;

        public static var name: String {
            return "SHA-256";
        }

    }
    
    public struct SHA512: HashAlgorithm {
        
        public typealias Hash = CryptoKit.SHA512;
        
        public static var name: String {
            return "SHA-512";
        }
        
    }
    
}
