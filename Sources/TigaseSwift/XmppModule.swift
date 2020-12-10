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

/** This is protocol which needs to be supported by every class which needs
 to be registered in `XmppModulesManager` and process incoming `Stanza`s
 */
public protocol XmppModule: class {
    
    static var ID: String { get }
    
    /// criteria used to match if this module should process particular stanza
    var criteria: Criteria { get };
    /// list of features supported by this module
    var features: [String] { get };
    
    /**
     This method is responsible for actual processing of `Stanza` instance.
     - throws: ErrorCondition - if processing resulted in an error
     */
    func process(stanza: Stanza) throws
    
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
    
    private var cancellables: [Cancellable] = [];
    
    public init() {}
            
    public func store(_ cancellable: Cancellable?) {
        guard let cancellable = cancellable else {
            return;
        }
        cancellables.append(cancellable);
    }
    
    public func write<Failure>(_ iq: Iq, timeout: TimeInterval, errorDecoder: @escaping PacketErrorDecoder<Failure>, completionHandler: ((Result<Iq, Failure>) -> Void)?) where Failure : Error {
        guard let writer = context?.writer else {
            completionHandler?(.failure(errorDecoder(nil) as! Failure));
            return;
        }
        writer.write(iq, timeout: timeout, errorDecoder: errorDecoder, completionHandler: completionHandler);
    }
    
    public func write(_ stanza: Stanza, writeCompleted: ((Result<Void, XMPPError>) -> Void)?) {
        guard let writer = context?.writer else {
            writeCompleted?(.failure(.remote_server_timeout));
            return;
        }
        writer.write(stanza, writeCompleted: writeCompleted);
    }

    public func fire(_ event: Event) {
        context?.eventBus.fire(event);
    }
}
