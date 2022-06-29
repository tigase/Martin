

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
    
    private class Entry {
        let identities: [DiscoveryModule.Identity];
        let features: [String];
        
        init(identities: [DiscoveryModule.Identity], features: [String]) {
            self.identities = identities;
            self.features = features;
        }
    }
        
    private var queue = DispatchQueue(label: "capabilities_cache_queue", attributes: DispatchQueue.Attributes.concurrent);
    
    private var entries: [String: Entry] = [:];
    
    public init() {
    }
    
    open func features(for node: String) -> [String]? {
        return queue.sync {
            return self.entries[node]?.features;
        }
    }
    
    open func identities(for node: String) -> [DiscoveryModule.Identity]? {
        return queue.sync {
            return self.entries[node]?.identities;
        }
    }
    
    open func nodes(withFeature feature: String) -> [String] {
        queue.sync {
            var result = Set<String>();
            for (node, entry) in self.entries {
                if entry.features.firstIndex(of: feature) != nil {
                    result.insert(node);
                }
            }
            return Array(result);
        }
    }
    
    open func isCached(node: String, handler: @escaping (Bool)->Void) {
        queue.async {
            let result = self.entries.index(forKey: node) != nil;
            handler(result);
        }
    }
    
    open func isSupported(feature: String, for node: String) -> Bool {
        return features(for: node)?.contains(feature) ?? false;
    }
    
    open func store(node: String, identities: [DiscoveryModule.Identity], features: [String]) {
        queue.async(flags: .barrier, execute: {
            self.entries[node] = .init(identities: identities, features: features);
        })
    }
}
