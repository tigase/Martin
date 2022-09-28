//
// Context.swift
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
 Instances of this class holds information passed to classes with support for `ContextAware` 
 protocol - mostly for implementations of `XmppModule` protocol.
 */
open class Context: CustomStringConvertible, Resetable, @unchecked Sendable {
    
    let queue = DispatchQueue(label: "context_queue");
    
    open var description: String {
        return connectionConfiguration.userJid.description;
    }
    
    public var userBareJid: BareJID {
        return connectionConfiguration.userJid;
    }
    
    private var _boundJid: JID?;
    public var boundJid: JID? {
        get {
            return withLock {
                return _boundJid;
            }
        }
        set {
            withLock {
                _boundJid = newValue
            }
        }
    }
    
    public var currentConnectionDetails: XMPPSrvRecord?;
    public var connectionConfiguration: ConnectionConfiguration = ConnectionConfiguration() {
        willSet {
            if connectionConfiguration.userJid != newValue.userJid {
                queue.sync {
                    for lifecycleAware in self.lifecycleAwares {
                        lifecycleAware.deinitialize(context: self);
                    }
                }
            }
        }
        didSet {
            if connectionConfiguration.userJid != oldValue.userJid {
                queue.sync {
                    for lifecycleAware in self.lifecycleAwares {
                        lifecycleAware.initialize(context: self);
                    }
                }
            }
        }
    }
    // Instance of `XmppModuleManager` which keeps instances of every registered module for this connection/client
    public let modulesManager: XmppModulesManager;
    
    @Published
    open private(set) var state: XMPPClient.State = .disconnected(.none);
    open var isConnected: Bool {
        return self.state == .connected();
    }
    
    private let lock = UnfairLock();
    @discardableResult
    public func withLock<T>(body: ()->T) -> T {
        lock.lock();
        defer {
            lock.unlock()
        }
        return body();
    }

    public func withLock(body: () throws -> Void) rethrows {
        lock.lock();
        defer {
            lock.unlock()
        }
        try body();
    }
    
    // Instance of `PacketWriter` to use for sending stanzas
    open var writer: PacketWriter;
    
    private var lifecycleAwares: [ContextLifecycleAware] = [];
    
    init(modulesManager: XmppModulesManager, writer: PacketWriter = DummyPacketWriter()) {
        self.modulesManager = modulesManager;
        self.writer = writer;
        self.modulesManager.context = self;
    }
    
    deinit {
        withLock {
            for lifecycleAware in lifecycleAwares {
                lifecycleAware.deinitialize(context: self);
            }
        }
    }
    
    open func reset(scopes: Set<ResetableScope>) {
        modulesManager.reset(scopes: scopes);
        if scopes.contains(.session) {
            boundJid = nil;
        }
    }
    
    open func module<T: XmppModule>(_ identifier: XmppModuleIdentifier<T>) -> T {
        return modulesManager.module(identifier);
    }

    open func moduleOrNil<T: XmppModule>(_ identifier: XmppModuleIdentifier<T>) -> T? {
        return modulesManager.moduleOrNil(identifier);
    }

    open func module<T: XmppModule>(_ type: T.Type) -> T {
        return modulesManager.module(type);
    }

    open func moduleOrNil<T: XmppModule>(_ type: T.Type) -> T? {
        return modulesManager.moduleOrNil(type);
    }
    
    open func modules<T>(_ type: T.Type) -> [T] {
        return modulesManager.modules(type);
    }

    open func register(lifecycleAware: ContextLifecycleAware) {
        withLock {
            self.lifecycleAwares.append(lifecycleAware);
            lifecycleAware.initialize(context: self);
        }
    }
    
    open func unregister(lifecycleAware: ContextLifecycleAware) {
        withLock {
            lifecycleAware.deinitialize(context: self);
            self.lifecycleAwares.append(lifecycleAware);
        }
    }
    
    func update(state: XMPPClient.State) {
        withLock {
            guard state != self.state else {
                return;
            }
            self.state = state;
        }
    }
    
    func update(state newState: XMPPClient.State, precondition: (XMPPClient.State) throws ->Void) throws {
        try withLock {
            try precondition(state);
            self.state = newState;
        }
    }
}
