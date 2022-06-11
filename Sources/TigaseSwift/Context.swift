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
open class Context: CustomStringConvertible, Resetable {
    
    let dispatcher: QueueDispatcher = QueueDispatcher(label: "context_queue");
    
    open var description: String {
        return connectionConfiguration.userJid.stringValue;
    }
    
    public var userBareJid: BareJID {
        return connectionConfiguration.userJid;
    }
    
    public var boundJid: JID? {
        return moduleOrNil(.resourceBind)?.bindedJid;
    }
    public var currentConnectionDetails: XMPPSrvRecord?;
    public var connectionConfiguration: ConnectionConfiguration = ConnectionConfiguration() {
        willSet {
            if connectionConfiguration.userJid != newValue.userJid {
                dispatcher.sync {
                    for lifecycleAware in self.lifecycleAwares {
                        lifecycleAware.deinitialize(context: self);
                    }
                }
            }
        }
        didSet {
            if connectionConfiguration.userJid != oldValue.userJid {
                dispatcher.sync {
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
        
    // Instance of `PacketWriter` to use for sending stanzas
    open var writer: PacketWriter;
    
    private var lifecycleAwares: [ContextLifecycleAware] = [];
    
    init(modulesManager: XmppModulesManager, writer: PacketWriter = DummyPacketWriter()) {
        self.modulesManager = modulesManager;
        self.writer = writer;
        self.modulesManager.context = self;
    }
    
    deinit {
        dispatcher.sync {
            for lifecycleAware in lifecycleAwares {
                lifecycleAware.deinitialize(context: self);
            }
        }
    }
    
    open func reset(scopes: Set<ResetableScope>) {
        modulesManager.reset(scopes: scopes);
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

    open func register(lifecycleAware: ContextLifecycleAware) {
        dispatcher.async {
            self.lifecycleAwares.append(lifecycleAware);
            lifecycleAware.initialize(context: self);
        }
    }
    
    open func unregister(lifecycleAware: ContextLifecycleAware) {
        dispatcher.async {
            lifecycleAware.deinitialize(context: self);
            self.lifecycleAwares.append(lifecycleAware);
        }
    }
    
    func update(state: XMPPClient.State) {
        guard state != self.state else {
            return;
        }
        self.state = state;
    }
}
