//
// DefaultCapabilitiesCache.swift
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
 Default implementation of in memory capabilities cache.
 
 Data stored in this cache will not be saved.
 */
public class DefaultCapabilitiesCache: CapabilitiesCache {
    
    /// Holds array of supported features grouped by node
    private var features = [String: [String]]();
    
    /// Holds identity for each node
    private var identities: [String: DiscoveryModule.Identity] = [:];
    
    private var queue = dispatch_queue_create("capabilities_cache_queue", DISPATCH_QUEUE_CONCURRENT);
    
    public func getFeatures(node: String) -> [String]? {
        var result: [String]?;
        dispatch_sync(queue) {
            result = self.features[node];
        }
        return result;
    }
    
    public func getIdentity(node: String) -> DiscoveryModule.Identity? {
        var result: DiscoveryModule.Identity?;
        dispatch_sync(queue) {
            result = self.identities[node];
        }
        return result;
    }
    
    public func getNodesWithFeature(feature: String) -> [String] {
        var result = Set<String>();
        for (node, features) in self.features {
            if features.indexOf(feature) != nil {
                result.insert(node);
            }
        }
        return Array(result);
    }
    
    public func isCached(node: String) -> Bool {
        var result = false;
        dispatch_sync(queue) {
            result = self.features.indexForKey(node) != nil;
        }
        return result;
    }
    
    public func store(node: String, identity: DiscoveryModule.Identity?, features: [String]) {
        dispatch_barrier_async(queue) {
            self.identities[node] = identity;
            self.features[node] = features;
        }
    }
}