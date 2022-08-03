//
// LogicPacketWriter.swift
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

/**
 Implementation of `PacketWriter` protocol passed to `Context` instance
 */
open class LogicPacketWriter: PacketWriter {
    
    let sessionLogic: XmppSessionLogic;
    let responseManager: ResponseManager;
    
    init(sessionLogic: XmppSessionLogic, responseManager: ResponseManager) {
        self.sessionLogic = sessionLogic;
        self.responseManager = responseManager;
    }
      
    public func write<Failure: Error>(_ iq: Iq, timeout: TimeInterval, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq, Failure>) -> Void)?) {
        if let completionHandler = completionHandler {
            let cancellable = responseManager.registerResponseHandler(for: iq, timeout: timeout, errorDecoder: errorDecoder, completionHandler: completionHandler);
        
            sessionLogic.send(stanza: iq, completionHandler: { result in
                switch result {
                case .success(_):
                    break;
                case .failure(_):
                    cancellable.cancel();
                }
            });
        } else {
            if iq.id == nil && (iq.type == .get || iq.type == .set) {
                iq.id = UIDGenerator.nextUid;
            }
            sessionLogic.send(stanza: iq)
        }
    }
    
    public func write(_ stanza: Stanza, writeCompleted: ((Result<Void, XMPPError>) -> Void)?) {
        if stanza.name == "iq" && stanza.id == nil {
            stanza.id = UUID().uuidString;
        }

        sessionLogic.send(stanza: stanza);
        writeCompleted?(.success(Void()));
    }
    
}
