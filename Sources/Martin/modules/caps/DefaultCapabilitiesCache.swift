

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
open class DefaultCapabilitiesCache: CapabilitiesCache {
    
    /// Holds array of supported features grouped by node
    fileprivate var features = [String: [String]]();
    
    /// Holds identity for each node
    fileprivate var identities: [String: DiscoveryModule.Identity] = [:];
    
    fileprivate var queue = DispatchQueue(label: "capabilities_cache_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    public init() {
    }
    
    open func getFeatures(for node: String) -> [String]? {
        var result: [String]?;
        queue.sync {
            result = self.features[node];
        }
        return result;
    }
    
    open func getIdentity(for node: String) -> DiscoveryModule.Identity? {
        var result: DiscoveryModule.Identity?;
        queue.sync {
            result = self.identities[node];
        }
        return result;
    }
    
    open func getNodes(withFeature feature: String) -> [String] {
        var result = Set<String>();
        for (node, features) in self.features {
            if features.firstIndex(of: feature) != nil {
                result.insert(node);
            }
        }
        return Array(result);
    }
    
    open func isCached(node: String, handler: @escaping (Bool)->Void) {
        queue.async {
            let result = self.features.index(forKey: node) != nil;
            handler(result);
        }
    }
    
    open func isSupported(for node: String, feature: String) -> Bool {
        return getFeatures(for: node)?.contains(feature) ?? false;
    }
    
    open func store(node: String, identity: DiscoveryModule.Identity?, features: [String]) {
        queue.async(flags: .barrier, execute: {
            self.identities[node] = identity;
            self.features[node] = features;
        }) 
    }
}
