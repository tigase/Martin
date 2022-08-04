//
// ResponseManager.swift
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
import TigaseLogging
import Combine

/**
 Class implements manager for registering requests sent to stream
 and their callbacks, and to retieve them when response appears
 in the stream.
 */
public actor ResponseManager {
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "ResponseManager")
    /// Internal class holding information about request and callbacks
    public struct Key: Hashable {
        let id: String;
        let jid: JID;
    }

    private struct Entry {
        let continuation: UnsafeContinuation<Iq,Error>;
        let timeoutTask: Task<Void,Error>;
        
        public func handleResponse(stanza: Stanza) -> Void {
            handleResponse(iq: stanza as! Iq)
        }
        
        public func handleResponse(iq: Iq) -> Void {
            timeoutTask.cancel();
            guard let error = XMPPError(iq) else {
                continuation.resume(returning: iq);
                return;
            }
            continuation.resume(throwing: error);
        }
    }
    
    public struct Condition: Equatable {
        let names: [String];
        let xmlns: String?;
        
        func matches(_ stanza: Stanza) -> Bool {
            if !names.isEmpty {
                guard names.contains(stanza.name) else {
                    return false;
                }
            }
            if let xmlns = xmlns {
                guard xmlns == stanza.xmlns else {
                    return false;
                }
            }
            return true;
        }
    }
    
    private struct ConditionEntry {
        let condition: Condition;
        let continuation: UnsafeContinuation<Stanza,Error>;
        let timeoutTask: Task<Void,Error>;
        
        public func handleResponse(stanza: Stanza) -> Void {
            timeoutTask.cancel();
            guard let error = XMPPError(stanza) else {
                continuation.resume(returning: stanza);
                return;
            }
            continuation.resume(throwing: error);
        }
    }
    
    private var iqHandlers = [Key: Entry](); //UnsafeContinuation<Iq,Error>]();
    private var conditionHandlers = [ConditionEntry]();
    
    private var accountJID: JID = JID("");
        
    public init() {
    }
    
    public func initialize(account: JID) {
        self.accountJID = account;
    }
    
    public func continuation(for stanza: Stanza) -> ((Stanza) -> Void)? {
        guard let iq = stanza as? Iq else {
            guard let idx = conditionHandlers.firstIndex(where: { $0.condition.matches(stanza) }) else {
                return nil;
            }
            let entry = conditionHandlers.remove(at: idx);
            return entry.handleResponse(stanza:);
        }
        guard let type = iq.type, let id = stanza.id, (type == StanzaType.error || type == StanzaType.result) else {
            return nil;
        }

        return self.iqHandlers.removeValue(forKey: .init(id: id, jid: stanza.from ?? accountJID))?.handleResponse(stanza:);
    }
    
    public func registerContinuation(_ continuation: UnsafeContinuation<Iq,Error>, for stanza: Iq, timeout: TimeInterval) -> Key {
        let id = idForStanza(stanza: stanza);
        let key = Key(id: id, jid: stanza.to ?? accountJID);
        self.iqHandlers[key] = .init(continuation: continuation, timeoutTask: Task {
            try await Task.sleep(nanoseconds: UInt64(timeout  * 1000_000_000));
            self.cancel(for: key, withError: XMPPError.remote_server_timeout);
        });

        return key;
    }

    public func registerContinuation(_ continuation: UnsafeContinuation<Stanza,Error>, for condition: Condition, timeout: TimeInterval) {
        conditionHandlers.append(.init(condition: condition, continuation: continuation, timeoutTask: Task {
            try await Task.sleep(nanoseconds: UInt64(timeout  * 1000_000_000));
            self.cancel(for: condition, withError: XMPPError.remote_server_timeout);
        }))
    }

    public func cancel(for key: Key , withError error: Error) {
        guard let entry = self.iqHandlers.removeValue(forKey: key) else {
            return;
        }
        entry.continuation.resume(throwing: error);
    }
    
    public func cancel(for condition: Condition, withError error: Error) {
        guard let idx = self.conditionHandlers.firstIndex(where: { $0.condition == condition }) else {
            return;
        }
        let entry = conditionHandlers.remove(at: idx);
        entry.continuation.resume(throwing: error);
    }
    
    private func idForStanza(stanza: Stanza) -> String {
        guard let id = stanza.id else {
            let id = UIDGenerator.nextUid;
            stanza.id = id;
            return id;
        }
        return id;
    }
    
    /// Deactivates response manager
    public func stop() {
        for entry in self.iqHandlers.values {
            entry.timeoutTask.cancel();
            entry.continuation.resume(throwing: XMPPError.remote_server_timeout);
        }
        self.iqHandlers.removeAll();
        for entry in self.conditionHandlers {
            entry.timeoutTask.cancel();
            entry.continuation.resume(throwing: XMPPError.remote_server_timeout);
        }
        self.conditionHandlers.removeAll();
    }
        
}
