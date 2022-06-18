//
// DummyPacketWriter.swift
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

public struct DummyPacketWriter: PacketWriter {
    
    public func write<Failure>(_ iq: Iq, timeout: TimeInterval, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq, Failure>) -> Void)?) where Failure : Error {
        completionHandler?(.failure(errorDecoder(nil) as! Failure));
    }
    
    public func write(_ stanza: Stanza, writeCompleted: ((Result<Void, XMPPError>) -> Void)?) {
        writeCompleted?(.failure(XMPPError.remote_server_timeout));
    }

}
