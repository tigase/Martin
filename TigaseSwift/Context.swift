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

public class Context {
    
    public let sessionObject:SessionObject;
    public let eventBus:EventBus;
    public let modulesManager:XmppModulesManager;
    
    public var writer:PacketWriter?;
    
    init(sessionObject:SessionObject, eventBus:EventBus, modulesManager:XmppModulesManager) {
        self.sessionObject = sessionObject;
        self.eventBus = eventBus;
        self.modulesManager = modulesManager;
        self.modulesManager.context = self;
    }
    
}