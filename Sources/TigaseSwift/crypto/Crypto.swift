//
// Crypto.swift
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

extension Digest {
    
    public func base64() -> String {
        return Data(self).base64EncodedString()
    }
    
    public func hex() -> String {
        return self.map({ String(format: "%02x", $0) }).joined();
    }
    
}

extension HashFunction {
    
    public static func hash(toBase64 string: String, using encoding: String.Encoding) -> String? {
        guard let data = string.data(using: encoding) else {
            return nil;
        }
        return hash(toBase64: data);
    }
    
    public static func hash<D>(toBase64 data: D) -> String where D: DataProtocol {
        return hash(data: data).base64();
    }
    
    public static func hash(toHex string: String, using encoding: String.Encoding) -> String? {
        guard let data = string.data(using: encoding) else {
            return nil;
        }
        return hash(toHex: data);
    }
    
    public static func hash<D>(toHex data: D) -> String where D: DataProtocol {
        return hash(data: data).hex();
    }
    
}
