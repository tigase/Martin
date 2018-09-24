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
open class Context {
    
    // Instance of `SessionObject` with properties for particular connection/client
    public let sessionObject: SessionObject;
    // Instance of `EventBus` which processes events for particular connection/client
    public let eventBus: EventBus;
    // Instance of `XmppModuleManager` which keeps instances of every registered module for this connection/client
    public let modulesManager: XmppModulesManager;
    // Instance of `PacketWriter` to use for sending stanzas
    open var writer: PacketWriter?;
    
    init(sessionObject: SessionObject, eventBus: EventBus, modulesManager: XmppModulesManager) {
        self.sessionObject = sessionObject;
        self.eventBus = eventBus;
        self.modulesManager = modulesManager;
        self.modulesManager.context = self;
    }
    
}
