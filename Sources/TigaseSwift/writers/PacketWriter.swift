//
// PacketWriter.swift
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

/** 
 Protocol defined to act as a protocol for classes extending it
 */
public typealias PacketErrorDecoder<Failure: Error> = (Stanza?) -> Error;

public protocol PacketWriter {
    
    func write(iq: Iq, timeout: TimeInterval, completionHandler: @escaping (Result<Iq, XMPPError>) -> Void)
        
    func write(stanza: Stanza, completionHandler: ((Result<Void,XMPPError>)->Void)?)
    
}

extension PacketWriter {

    public func write(iq: Iq, timeout: TimeInterval = 30.0, completionHandler: @escaping (Result<Iq,XMPPError>)->Void) {
        write(iq: iq, timeout: timeout, completionHandler: completionHandler);
    }

    public func write(stanza: Stanza) {
        write(stanza: stanza, completionHandler: nil);
    }
    
}

// async-await support
extension PacketWriter {
    
    public func write(stanza: Stanza) async throws {
        return try await withUnsafeThrowingContinuation { continuation in
            write(stanza: stanza, completionHandler: continuation.resume(with:));
        }
    }
    
    public func write(iq: Iq, timeout: TimeInterval = 30.0) async throws -> Iq {
        return try await withUnsafeThrowingContinuation({ continuation in
            write(iq: iq, timeout: timeout, completionHandler: continuation.resume(with:));
        })
    }

}
