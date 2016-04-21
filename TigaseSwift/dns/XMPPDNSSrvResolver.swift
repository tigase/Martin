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

public class XMPPDNSSrvResolver : Logger {
    
    var domain:String!;
    var srvRecords = [XMPPSrvRecord]();
    weak var connector:SocketConnector!;

    func resolve(domain:String, connector:SocketConnector) -> Void {
        self.domain = domain;
        self.srvRecords.removeAll();
        self.connector = connector;
        let err = DNSQuerySRVRecord("_xmpp-client._tcp." + domain + ".", XMPPDNSSrvResolver.bridge(self), { (record:UnsafeMutablePointer<DNSSrvRecord>, resolverPtr:UnsafeMutablePointer<Void>) -> Void in
            let r = record.memory;
            let port = Int(r.port);
            let weight = Int(r.weight);
            let priority = Int(r.priority);
            let target = String(CString: UnsafePointer<CChar>(r.target), encoding: NSISOLatin1StringEncoding)
            Log.log("received: ", r.priority, r.weight, r.port, target);
            let rec = XMPPSrvRecord(port: port, weight: weight, priority: priority, target: target!);
            let resolver:XMPPDNSSrvResolver = XMPPDNSSrvResolver.bridge(resolverPtr);
            resolver.srvRecords.append(rec);
            }, { (err:Int32, resolverPtr:UnsafeMutablePointer<Void>) -> Void in
                let resolver:XMPPDNSSrvResolver = XMPPDNSSrvResolver.bridge(resolverPtr);
                resolver.resolved();
        });
        log("dns returned code: ", err);
    }
    
    func resolved() {
        srvRecords.sortInPlace { (a,b) -> Bool in
            if (a.priority < b.priority) {
                return true;
            } else if (a.priority > b.priority) {
                return false;
            } else {
                return a.weight > b.weight;
            }
        }
        connector.connect(domain, dnsRecords: srvRecords);
        connector = nil;
    }
    
    static func bridge<T : AnyObject>(obj : T) -> UnsafeMutablePointer<Void> {
        return UnsafeMutablePointer(Unmanaged.passUnretained(obj).toOpaque());
    }
    
    static func bridge<T : AnyObject>(ptr : UnsafeMutablePointer<Void>) -> T {
        return Unmanaged<T>.fromOpaque(COpaquePointer(ptr)).takeUnretainedValue();
    }
}