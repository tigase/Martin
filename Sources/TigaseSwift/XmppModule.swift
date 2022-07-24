//
// XmppModule.swift
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
import Combine

/** This is protocol which needs to be supported by every class which needs
 to be registered in `XmppModulesManager` and process incoming `Stanza`s
 */
public protocol XmppModule: AnyObject, Sendable {
    
    static var ID: String { get }
    
    /// list of features supported by this module
    var features: [String] { get };
        
}

public protocol XmppStanzaProcessor: XmppModule {
    
    /// criteria used to match if this module should process particular stanza
    var criteria: Criteria { get };
    
    /**
     This method is responsible for actual processing of `Stanza` instance.
     - throws: ErrorCondition - if processing resulted in an error
     */
    func process(stanza: Stanza) async throws

}

extension AnyCancellable {
    
    public func store(in module: XmppModuleBase) {
        module.store(self);
    }
    
}

open class XmppModuleBase: ContextAware, PacketWriter {
        
    open weak var context: Context? {
        didSet {
            for cancellable in cancellables {
                cancellable.cancel();
            }
            cancellables.removeAll();
        }
    }
    
    private var cancellables: Set<AnyCancellable> = [];
    
    public init() {}
            
    public func store(_ cancellable: AnyCancellable?) {
        cancellable?.store(in: &cancellables);
    }
    
    public func write(stanza: Stanza, for condition: ResponseManager.Condition, timeout: TimeInterval) async throws -> Stanza {
        guard let writer = context?.writer else {
            throw XMPPError(condition: .remote_server_timeout);
        }
        return try await writer.write(stanza: stanza, for: condition, timeout: timeout);
    }
    
    @discardableResult
    public func write(iq: Iq, timeout: TimeInterval = 30.0) async throws -> Iq {
        guard let writer = context?.writer else {
            throw XMPPError(condition: .remote_server_timeout);
        }
        return try await writer.write(iq: iq, timeout: timeout);
    }
    
    public func write(stanza: Stanza) async throws {
        guard let writer = context?.writer else {
            throw XMPPError(condition: .remote_server_timeout);
        }
        return try await writer.write(stanza: stanza);
    }

}

// async-await support
extension XmppModuleBase {
    
    
    public func write(iq: Iq, timeout: TimeInterval, completionHandler: @escaping (Result<Iq, XMPPError>) -> Void) {
        guard let writer = context?.writer else {
            completionHandler(.failure(XMPPError(condition: .remote_server_timeout)));
            return;
        }
        writer.write(iq: iq, timeout: timeout, completionHandler: completionHandler);
    }
    
    public func write(stanza: Stanza, completionHandler: ((Result<Void, XMPPError>) -> Void)?) {
        guard let writer = context?.writer else {
            completionHandler?(.failure(.remote_server_timeout));
            return;
        }
        writer.write(stanza: stanza, completionHandler: completionHandler);
    }
    
}
