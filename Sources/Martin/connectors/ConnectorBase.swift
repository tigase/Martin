//
// ConnectorBase.swift
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
import Combine
import os

open class ConnectorBase {
    
    @Published
    public var state: ConnectorState = .disconnected(.none)

    public var statePublisher: Published<ConnectorState>.Publisher {
        return $state;
    }
 
    public let streamEvents = PassthroughSubject<StreamEvent,Never>();
 
    public var streamEventsPublisher: AnyPublisher<StreamEvent,Never> {
        return streamEvents.eraseToAnyPublisher();
    }
    
    public var availableFeatures: Set<ConnectorFeature> = [];
    public var activeFeatures: Set<ConnectorFeature> = [];
    
    public let logger = Logger(subsystem: "TigaseSwift", category: "ConnectorBase")
    
    public var streamLogger: StreamLogger?;
    
    open weak var context: Context?;
    
    required public init(context: Context) {
        self.context = context;
    }

}
