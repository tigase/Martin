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
    
    func write<Failure: Error>(_ iq: Iq, timeout: TimeInterval, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq, Failure>) -> Void)?)
        
    func write(_ stanza: Stanza, writeCompleted: ((Result<Void,XMPPError>)->Void)?)

    
}

extension PacketWriter {

    public func write(_ iq: Iq, timeout: TimeInterval = 30.0, completionHandler: ((Result<Iq,XMPPError>)->Void)?) {
        write(iq, timeout: timeout, errorDecoder: XMPPError.from(stanza: ), completionHandler: completionHandler);
    }

    public func write<Failure: Error>(_ iq: Iq, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq,Failure>)->Void)?) {
        write(iq, timeout: 30.0, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }

    public func write(_ stanza: Stanza) {
        write(stanza, writeCompleted: nil);
    }

}
