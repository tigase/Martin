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
import TigaseLogging

open class DNSSrvResolverWithCache: DNSSrvResolver {
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "DNSSrvResolverWithCache");
    private let dispatcher = QueueDispatcher(label: "DnsSrvResolverWithCache");
    fileprivate let resolver: DNSSrvResolver;
    fileprivate let cache: DNSSrvResolverCache;
    fileprivate let automaticRefresh: Bool;
    
    public init(resolver: DNSSrvResolver, cache: DNSSrvResolverCache, withAutomaticRefresh: Bool = true) {
        self.resolver = resolver;
        self.cache = cache;
        self.automaticRefresh = withAutomaticRefresh;
    }
    
    open func resolve(domain: String, for jid: BareJID, completionHandler: @escaping (_ result: Result<XMPPSrvResult,DNSError>) -> Void) {
        self.dispatcher.async {
            if let records = self.cache.getRecords(for: domain), records.hasValid {
                self.logger.log("loaded DNS records for domain: \(domain) from cache \(records.records)");
                completionHandler(.success(records));
                
                guard self.automaticRefresh else {
                    return;
                }
                
                self.resolver.resolve(domain: domain, for: jid) { dnsResult in
                    self.logger.log("dns resolution finished: \(dnsResult)");
                    switch dnsResult {
                    case .success(let records):
                        self.save(for: domain, result: records);
                    default:
                        // nothing to do..
                        break;
                    }
                };
            } else {
                self.resolver.resolve(domain: domain, for: jid, completionHandler: { dnsResult in
                    switch dnsResult {
                    case .success(let records):
                        self.save(for: domain, result: records);
                    default:
                        break;
                    }
                    completionHandler(dnsResult);
                });
            }
        }
    }
    
    public func markAsInvalid(for domain: String, record: XMPPSrvRecord, for period: TimeInterval) {
        self.dispatcher.async {
            self.resolver.markAsInvalid(for: domain, record: record, for: period);
            self.cache.markAsInvalid(for: domain, record: record, for: period);
        }
    }
    
    fileprivate func save(for domain: String, result: XMPPSrvResult?) {
        guard let current = cache.getRecords(for: domain) else {
            cache.store(for: domain, result: result);
            return;
        }
        guard current.update(fromQuery: result?.records ?? []) else {
            return;
        }
        cache.store(for: domain, result: current);
    }
    
    open class InMemoryCache: DNSSrvResolverCache {
        
        private let store: DNSSrvResolverCache?;
        
        private let cache = NSCache<NSString, XMPPSrvResult>();
        
        public init(store: DNSSrvResolverCache?) {
            self.store = store;
        }
        
        public func getRecords(for domain: String) -> XMPPSrvResult? {
            let key = NSString(string: domain);
            if let records = cache.object(forKey: key) {
                return records;
            }
            if let records = store?.getRecords(for: domain) {
                cache.setObject(records, forKey: key);
                return records;
            }
            return nil;
        }
        
        public func markAsInvalid(for domain: String, record: XMPPSrvRecord, for period: TimeInterval) {
            guard let current = getRecords(for: domain) else {
                return;
            }
            current.markAsInvalid(record: record, for: period);
            self.save(for: domain, result: current);
        }
        
        public func store(for domain: String, result: XMPPSrvResult?) {
            self.save(for: domain, result: result);
        }
        
        private func save(for domain: String, result: XMPPSrvResult?) {
            let key = NSString(string: domain);
            if let r = result {
                cache.setObject(r, forKey: key)
            } else {
                cache.removeObject(forKey: key);
            }
            store?.store(for: domain, result: result);
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
        
        open func getRecords(for domain: String) -> XMPPSrvResult? {
            let fileUrl = pathUrl.appendingPathComponent(domain);
            guard fileManager.fileExists(atPath: fileUrl.path) else {
                return nil;
            }
            guard let data = try? Data(contentsOf: fileUrl) else {
                return nil;
            }
            guard let result = try? JSONDecoder().decode(XMPPSrvResult.self, from: data), result.hasValid else {
                return nil;
            }
            return result;
        }
     
        open func markAsInvalid(for domain: String, record: XMPPSrvRecord, for period: TimeInterval) {
            guard let current = getRecords(for: domain) else {
                return;
            }
            current.markAsInvalid(record: record, for: period);
            self.save(for: domain, result: current);
        }
        
        open func store(for domain: String, result: XMPPSrvResult?) {
            self.save(for: domain, result: result);
        }
        
        fileprivate func save(for domain: String, result: XMPPSrvResult?) {
            let fileUrl = pathUrl.appendingPathComponent(domain);
            if result != nil {
                if let data = try? JSONEncoder().encode(result!) {
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

public protocol DNSSrvResolverCache: class {
    
    func getRecords(for domain: String) -> XMPPSrvResult?;
    
    func markAsInvalid(for domain: String, record: XMPPSrvRecord, for period: TimeInterval);
    
    func store(for domain: String, result: XMPPSrvResult?);
    
}
