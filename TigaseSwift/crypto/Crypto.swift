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
import CommonCrypto

protocol DigestProtocol {
    func digest(bytes: UnsafePointer<Void>, length: Int) -> [UInt8];
}

public enum Digest: DigestProtocol {
    
    case MD5
    case SHA1
    case SHA256
    
    public func digest(bytes: UnsafePointer<Void>, length inLength: Int) -> [UInt8] {
        let length = UInt32(inLength);
        switch self {
        case .MD5:
            var hash = [UInt8](count: Int(CC_MD5_DIGEST_LENGTH), repeatedValue: 0);
            CC_MD5(bytes, length, &hash);
            return hash;
        case .SHA1:
            var hash = [UInt8](count: Int(CC_SHA1_DIGEST_LENGTH), repeatedValue: 0);
            CC_SHA1(bytes, length, &hash);
            return hash;
        case .SHA256:
            var hash = [UInt8](count: Int(CC_SHA256_DIGEST_LENGTH), repeatedValue: 0);
            CC_SHA256(bytes, length, &hash);
            return hash;
        }
    }
    
    public func digest(data: NSData?) -> [UInt8]? {
        guard data != nil else {
            return nil;
        }
        return self.digest(data!.bytes, length: data!.length);
    }
    
    public func digest(data: NSData?) -> NSData? {
        if var hash:[UInt8] = self.digest(data) {
            let ptr = Digest.convert(&hash);
            return NSData(bytes: ptr, length: hash.count);
        }
        return nil;
    }
    
    public func digestToBase64(data: NSData?) -> String? {
        let result:NSData? = digest(data);
        return result?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0));
    }
    
    public func digestToHex(data: NSData?) -> String? {
        if let result:[UInt8] = digest(data) {
            return result.map() { String(format: "%02X", $0) }.reduce("", combine: +);
        }
        return nil;
    }
    
    private static func convert(ptr: UnsafePointer<UInt8>) -> UnsafePointer<Void> {
        return UnsafePointer<Void>(ptr);
    }
}