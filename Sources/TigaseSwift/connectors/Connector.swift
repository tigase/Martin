//
// Connector.swift
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

public protocol Connector: AnyObject {
    
    static var supportedProtocols: [ConnectorProtocol] { get }
    
    var state: ConnectorState { get }
    var statePublisher: Published<ConnectorState>.Publisher { get }
    var streamEventsPublisher: AnyPublisher<StreamEvent,Never> { get }
    
    var availableFeatures: Set<ConnectorFeature> { get }
    var activeFeatures: Set<ConnectorFeature> { get }
    
    var streamLogger: StreamLogger? { get set }
    
    var currentEndpoint: ConnectorEndpoint? { get }
    
    init(context: Context);
    
    func activate(feature: ConnectorFeature);
    
    func start(endpoint: ConnectorEndpoint?);
    
    func stop(force: Bool) -> Future<Void,Never>;
    
    func restartStream();
    
    func send(_ data: StreamEvent, completion: WriteCompletion);
     
    func prepareEndpoint(withResumptionLocation location: String?) -> ConnectorEndpoint?;
    
    func prepareEndpoint(withSeeOtherHost seeOtherHost: String?) -> ConnectorEndpoint?;
    
}

public protocol ConnectorEndpoint {
    
    var proto: ConnectorProtocol { get }
    
}

extension Connector {
    
    public func stop() -> Future<Void,Never> {
        return stop(force: false);
    }
    
    public func send(_ data: StreamEvent) {
        self.send(data, completion: .none);
    }
}
