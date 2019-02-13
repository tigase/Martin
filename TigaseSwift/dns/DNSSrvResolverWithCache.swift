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
        fileprivate let pathUrl: URL;
        
        public init(cacheDirectoryName: String = "dns_cache") {
            fileManager = FileManager.default;
            let url = try! fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true);
            pathUrl = url.appendingPathComponent(cacheDirectoryName, isDirectory: true);//.path;
            createDirectory();
        }
        
        open func getRecords(for domain: String) -> [XMPPSrvRecord]? {
            let fileUrl = pathUrl.appendingPathComponent(domain);
            guard fileManager.fileExists(atPath: fileUrl.path) else {
                return nil;
            }
            guard let data = try? Data(contentsOf: fileUrl) else {
                return nil;
            }
            return try? JSONDecoder().decode([XMPPSrvRecord].self, from: data);
        }
        
        open func store(for domain: String, records: [XMPPSrvRecord]?) {
            let fileUrl = pathUrl.appendingPathComponent(domain);
            if records != nil {
                if let data = try? JSONEncoder().encode(records!) {
                    try? data.write(to: fileUrl);
                }
            } else {
                try? fileManager.removeItem(atPath: fileUrl.path);
            }
        }
        
        fileprivate func createDirectory() {
            guard !fileManager.fileExists(atPath: pathUrl.path) else {
                return;
            }
            
            try! fileManager.createDirectory(atPath: pathUrl.path, withIntermediateDirectories: true, attributes: nil);
        }
    }
}

public protocol DNSSrvResolverCache {
    
    func getRecords(for domain: String) -> [XMPPSrvRecord]?;
    
    func store(for domain: String, records: [XMPPSrvRecord]?);
    
}
