//
// NetworkMonitor.swift
//
// TigaseSwift
// Copyright (C) 2021 "Tigase, Inc." <office@tigase.com>
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
import Network
import os

extension NWPath: @retroactive CustomStringConvertible {
    
    public var description: String {
        String(reflecting: self)
    }
    
}

open class NetworkMonitor {
    
    public static let shared = NetworkMonitor();
    
    public let logger = Logger(subsystem: "TigaseSwift", category: "NetworkManager");
    public let monitor: NWPathMonitor;
    public let queue: DispatchQueue;
    
    @Published
    public private(set) var currentPath: NWPath {
        didSet {
            logger.debug("network state changed: \(self.currentPath.status == .satisfied), path: \(self.currentPath)")
            let available = currentPath.status == .satisfied;
            if available != isNetworkAvailable {
                isNetworkAvailable = available;
            }
        }
    }
    
    @Published
    public private(set) var isNetworkAvailable: Bool = false;
    
    public init(monitor: NWPathMonitor = NWPathMonitor(), queue: DispatchQueue = DispatchQueue(label: "NetworkMonitor")) {
        self.monitor = monitor;
        self.currentPath = self.monitor.currentPath;
        self.queue = queue;
        self.monitor.pathUpdateHandler = { [weak self] newPath in
            self?.currentPath = newPath;
        }
        self.monitor.start(queue: queue);
    }
    
    deinit {
        self.monitor.cancel();
    }
        
}
