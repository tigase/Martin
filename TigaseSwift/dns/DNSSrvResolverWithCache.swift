//
// DNSSrvResolverWithCache.swift
//
// TigaseSwift
// Copyright (C) 2018 "Tigase, Inc." <office@tigase.com>
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

open class DNSSrvResolverWithCache: Logger, DNSSrvResolver {    
    
    fileprivate let resolver: DNSSrvResolver;
    fileprivate let cache: DNSSrvResolverCache;
    fileprivate let automaticRefresh: Bool;
    
    public init(resolver: DNSSrvResolver, cache: DNSSrvResolverCache, withAutomaticRefresh: Bool = true) {
        self.resolver = resolver;
        self.cache = cache;
        self.automaticRefresh = withAutomaticRefresh;
    }
    
    open func resolve(domain: String, completionHandler: @escaping ([XMPPSrvRecord]?) -> Void) {
        let records = cache.getRecords(for: domain)
        if records != nil {
            log("loaded DNS records from cache");
            completionHandler(records);
            guard automaticRefresh else {
                return;
            }
        }

        if records == nil {
            self.resolver.resolve(domain: domain, completionHandler: { records in
                self.cache.store(for: domain, records: records);
                completionHandler(records);
            });
        } else {
            DispatchQueue.global(qos: .utility).async {
                self.resolver.resolve(domain: domain, completionHandler: { records in
                    if records != nil {
                        self.cache.store(for: domain, records: records);
                    }
                });
            }
        }
    }
    
    open class DiskCache: DNSSrvResolverCache {
        
        fileprivate let fileManager: FileManager;
        fileprivate let path: String;
        
        public init(cacheDirectoryName: String = "dns_cache") {
            fileManager = FileManager.default;
            let url = try! fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true);
            path = url.appendingPathComponent(cacheDirectoryName, isDirectory: true).path;
            createDirectory();
        }
        
        open func getRecords(for domain: String) -> [XMPPSrvRecord]? {
            let filePath = path + "/" + domain;
            guard fileManager.fileExists(atPath: filePath) else {
                return nil;
            }
            
            return NSKeyedUnarchiver.unarchiveObject(withFile: filePath) as? [XMPPSrvRecord];
        }
        
        open func store(for domain: String, records: [XMPPSrvRecord]?) {
            let filePath = path + "/" + domain;
            if records != nil {
                NSKeyedArchiver.archiveRootObject(records!, toFile: filePath);
            } else {
                try? fileManager.removeItem(atPath: filePath);
            }
        }
        
        fileprivate func createDirectory() {
            guard !fileManager.fileExists(atPath: path) else {
                return;
            }
            
            try! fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil);
        }
    }
}

public protocol DNSSrvResolverCache {
    
    func getRecords(for domain: String) -> [XMPPSrvRecord]?;
    
    func store(for domain: String, records: [XMPPSrvRecord]?);
    
}
