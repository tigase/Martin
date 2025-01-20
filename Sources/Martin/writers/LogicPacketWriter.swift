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
public struct LogicPacketWriter: PacketWriter {
    
    private let sessionLogic: XmppSessionLogic;
    private let responseManager: ResponseManager;
    
    private let iqRequestTypes: Set<StanzaType> = [.get, .set];
    
    init(sessionLogic: XmppSessionLogic, responseManager: ResponseManager) {
        self.sessionLogic = sessionLogic;
        self.responseManager = responseManager;
    }
    
    public func write(stanza: Stanza, for condition: ResponseManager.Condition, timeout: TimeInterval) async throws -> Stanza {
        try await withUnsafeThrowingContinuation({ continuation in
            Task {
                await responseManager.registerContinuation(continuation, for: condition, timeout: timeout);
                do {
                    try await sessionLogic.send(stanza: stanza)
                } catch {
                    await responseManager.cancel(for: condition, withError: error);
                }
            }
        })
    }
      
    public func write(iq: Iq, timeout: TimeInterval) async throws -> Iq {
        guard let type = iq.type else {
            throw XMPPError(condition: .bad_request, message: "IQ stanza requires `type`!");
        }
        guard iqRequestTypes.contains(type) else {
            fatalError("This method can only be used for sending iq requests and not responses!");
        }
        return try await withUnsafeThrowingContinuation({ continuation in
            Task {
                let key = await responseManager.registerContinuation(continuation, for: iq, timeout: timeout);
                do {
                    try await sessionLogic.send(stanza: iq)
                } catch {
                    await responseManager.cancel(for: key, withError: error);
                }
            }
        })
    }
    
    public func write(stanza: Stanza) async throws {
        if stanza.name == "iq" {
            guard let type = stanza.type else {
                throw XMPPError(condition: .bad_request, message: "IQ stanza requires `type`!");
            }
            if iqRequestTypes.contains(type) {
                if stanza.id == nil {
                    stanza.id = UIDGenerator.nextUid;
                }
            }
        }

        try await sessionLogic.send(stanza: stanza);
    }
    
}
