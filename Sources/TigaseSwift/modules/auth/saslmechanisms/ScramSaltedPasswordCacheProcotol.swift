//
// ScramSaltedPasswordCacheProcotol.swift
//
// TigaseSwift
// Copyright (C) 2018 "Tigase, Inc." <office@tigase.com>
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

/**
 Protocol for a class providing implementation of a caching functionality for salted version
 of a password used during authentication using SCRAM mechanism.
 This may improve performance and reduce battery usage as generation of salted version is
 a CPU intensive task.
 */
public protocol ScramSaltedPasswordCacheProtocol {
    
    /**
     Retrive salted version of a password for provided parameters
     - parameter for: instance of `Context`
     - parameter id: id of a salted password generated using `generateId()` method
     */
    func getSaltedPassword(for: Context, id: String) -> Data?;
    
    /**
     Store salted version of a password for future usage
     - parameter for: instance of `Context`
     - parameter id: id of a salted password generated using `generateId()` method
     - parameter saltedPassword: actual value of a salted password
     
     - Node:
     This method should clear any other salted password values stored for passed instance of a `SessionObject`.
    */
    func store(for: Context, id: String, saltedPassword: Data);
    
    /**
     Clear all cached salted passwords for particular session object
     - parameter for: instance of `SessionObject`
    */
    func clearCache(for: Context);
 
}

extension ScramSaltedPasswordCacheProtocol {
    
    func generateId(algorithm: ScramAlgorithm, salt: Foundation.Data, iterations: Int) -> String {
        let tmp = algorithm.name.data(using: .utf8)! + String(iterations).data(using: .utf8)! + salt;
        return Insecure.SHA1.hash(toHex: tmp);
    }
    
}

open class DefaultScramSaltedPasswordCache: ScramSaltedPasswordCacheProtocol {

    public static let SALTED_ID_KEY = "scramSaltedId";
    public static let SALTED_PASSWORD_KEY = "scramSaltedPassword";
    
    private var cache: [BareJID: Entry] = [:];
    
    public init() {
    }
    
    public func getSaltedPassword(for context: Context, id: String) -> Data? {
        guard let entry = cache[context.userBareJid] else {
            return nil;
        }
        guard id == entry.id else {
            cache.removeValue(forKey: context.userBareJid);
            return nil;
        }
        return entry.saltedPassword;
    }
    
    public func store(for context: Context, id: String, saltedPassword: Data) {
        cache[context.userBareJid] = Entry(id: id, saltedPassword: saltedPassword);
    }
    
    public func clearCache(for context: Context) {
        cache.removeValue(forKey: context.userBareJid);
    }
    
    class Entry {
        let id: String;
        let saltedPassword: Data;
        
        init(id: String, saltedPassword: Data) {
            self.id = id;
            self.saltedPassword = saltedPassword;
        }
    }
}
