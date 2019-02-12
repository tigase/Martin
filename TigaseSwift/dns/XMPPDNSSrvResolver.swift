//
// DNSSrvResorver.swift
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
 Class used to resolve DNS XMPP SRV records.
 
 Returns resolved IP address if there is no SRV entries for domain
 */
open class XMPPDNSSrvResolver: Logger, DNSSrvResolver {
    
    var directTlsEnabled: Bool = true;
    
    /**
     Resolve XMPP SRV records for domain
     - parameter domain: domain name to resolve
     - parameter completionHandler: handler to be called after DNS resoltion is finished
     */
    open func resolve(domain: String, completionHandler: @escaping ([XMPPSrvRecord]?) -> Void) {
        guard !domain.hasSuffix(".local") else {
            completionHandler([XMPPSrvRecord]());
            return;
        }
        
        if self.directTlsEnabled {
            self.resolveXmppSRV(domain: domain, service: "_xmpps-client", proto: "_tcp") { (result1) in
                self.resolveXmppSRV(domain: domain, service: "_xmpp-client", proto: "_tcp") { (result2) in
                    guard result1 != nil || result2 != nil else {
                        completionHandler(nil);
                        return;
                    }
                    
                    var result = [XMPPSrvRecord]();
                    if (result1 != nil) {
                        result.append(contentsOf: result1!);
                    }
                    if (result2 != nil) {
                        result.append(contentsOf: result2!);
                    }
                    completionHandler(result.sorted { (a,b) -> Bool in
                            if (a.priority < b.priority) {
                                return true;
                            } else if (a.priority > b.priority) {
                                return false;
                            } else {
                                return a.weight > b.weight;
                            }
                    });
                }
            }
        } else {
            self.resolveXmppSRV(domain: domain, service: "_xmpp-client", proto: "_tcp") { (result2) in
                completionHandler(result2);
            }
        }
    }
    
    open func resolveXmppSRV(domain: String, service: String, proto: String, completionHandler: @escaping ([XMPPSrvRecord]?)->Void) {
        guard !domain.hasSuffix(".local") else {
            completionHandler([XMPPSrvRecord]());
            return;
        }
        
        let ctx = DNSCtx(service: service, completionHandler: completionHandler);
        
        let err = DNSQuerySRVRecord("\(service).\(proto).\(domain).", XMPPDNSSrvResolver.bridge(ctx), { (record:UnsafeMutablePointer<DNSSrvRecord>?, ctxPtr:UnsafeMutableRawPointer?) -> Void in
            let r = record!.pointee;
            let port = Int(r.port);
            let weight = Int(r.weight);
            let priority = Int(r.priority);
            guard let target = String(cString: UnsafePointer<CChar>(r.target), encoding: String.Encoding.isoLatin1) else {
                return;
            }
            Log.log("received: ", r.priority, r.weight, r.port, target);
            let dnsCtx: DNSCtx = XMPPDNSSrvResolver.bridge(ctxPtr!);
            let rec = XMPPSrvRecord(port: port, weight: weight, priority: priority, target: target, directTls: dnsCtx.service.starts(with: "_xmpps-"));
            dnsCtx.srvRecords.append(rec);
        }, { (err:Int32, ctxPtr:UnsafeMutableRawPointer?) -> Void in
            let dnsCtx: DNSCtx = XMPPDNSSrvResolver.bridge(ctxPtr!);
            dnsCtx.finished(err);
        });
        log("dns returned code: ", err, "for \(service).\(proto). at", domain);
        
        if err != 0 {
            ctx.finished(err);
        }
    }
    
//    /**
//     Resolve XMPP SRV records for domain
//     - parameter domain: domain name to resolve
//     - parameter connector: instance of `SocketConnector` to call when DNS resolution is finished
//     */
//    func resolve(domain:String, connector:SocketConnector) -> Void {
//        self.domain = domain;
//        self.srvRecords.removeAll();
//        self.connector = connector;
//
//        // we do not want to use DNS resolution for ".local" domain as it is pointless and only takes time..
//        guard !domain.hasSuffix(".local") else {
//            self.resolved();
//            return;
//        }
//        let err = DNSQuerySRVRecord("_xmpp-client._tcp." + domain + ".", XMPPDNSSrvResolver.bridge(self), { (record:UnsafeMutablePointer<DNSSrvRecord>?, resolverPtr:UnsafeMutableRawPointer?) -> Void in
//            let r = record!.pointee;
//            let port = Int(r.port);
//            let weight = Int(r.weight);
//            let priority = Int(r.priority);
//            let target = String(cString: UnsafePointer<CChar>(r.target), encoding: String.Encoding.isoLatin1)
//            Log.log("received: ", r.priority, r.weight, r.port, target);
//            let rec = XMPPSrvRecord(port: port, weight: weight, priority: priority, target: target!);
//            let resolver:XMPPDNSSrvResolver = XMPPDNSSrvResolver.bridge(resolverPtr!);
//            resolver.srvRecords.append(rec);
//            }, { (err:Int32, resolverPtr:UnsafeMutableRawPointer?) -> Void in
//                let resolver:XMPPDNSSrvResolver = XMPPDNSSrvResolver.bridge(resolverPtr!);
//                resolver.resolved();
//        });
//        log("dns returned code: ", err, "for _xmpp-client._tcp. at", domain);
//        if err < 0 {
//            resolved();
//        }
//    }
    
    static func bridge<T : AnyObject>(_ obj : T) -> UnsafeMutableRawPointer {
        return Unmanaged.passUnretained(obj).toOpaque();
    }
    
    static func bridge<T : AnyObject>(_ ptr : UnsafeMutableRawPointer) -> T {
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue();
    }

    class DNSCtx {
        let service: String;
        var srvRecords = [XMPPSrvRecord]();
        var completionHandler: ([XMPPSrvRecord]?) -> Void;
        
        init(service: String, completionHandler: @escaping ([XMPPSrvRecord]?) -> Void) {
            self.service = service;
            self.completionHandler = completionHandler;
        }
        
        func finished(_ err: Int32) {
            guard err == 0 else {
                completionHandler(nil);
                return;
            }
            
            if #available(iOSApplicationExtension 11.0, *) {
            } else {
                srvRecords = srvRecords.filter({ (rec) -> Bool in
                    return rec.directTls == false;
                });
            }
            
            srvRecords.sort { (a,b) -> Bool in
                if (a.priority < b.priority) {
                    return true;
                } else if (a.priority > b.priority) {
                    return false;
                } else {
                    return a.weight > b.weight;
                }
            }
            completionHandler(srvRecords);
        }
    }
}
