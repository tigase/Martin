//
// XMPPSrvRecord.swift
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
import dnssd
import DNS_Util

/**
 Class holds informations for single SRV record of DNS entries
 */
open class XMPPSrvRecord: Codable, Equatable, CustomStringConvertible {
    
    public static func == (lhs: XMPPSrvRecord, rhs: XMPPSrvRecord) -> Bool {
        return lhs.port == rhs.port && lhs.target == rhs.target && lhs.directTls == rhs.directTls && lhs.weight == rhs.weight && lhs.priority == rhs.priority;
    }
    
    var isValid: Bool {
        guard let invalid = self.invalid else {
            return true;
        }
        return Date().compare(invalid) == .orderedDescending;
    }
    
    let port:Int;
    let weight:Int;
    let priority:Int;
    let target:String;
    let directTls: Bool;
    fileprivate var invalid: Date?;

    open var description: String {
        return "[port: \(String(describing: port)), weight: \(weight), priority: \(String(describing: priority)), target: \(target), directTls: \(directTls), isValid: \(isValid)]";
    }
    
    public convenience init?(parse: UnsafePointer<UInt8>?, length: UInt16?) {
        guard let rdata = parse, let rdlen = length else {
            return nil;
        }
        
        let rrDataLen = 1+2+2+4+2+Int(rdlen);
        var rrData = Data(capacity: rrDataLen);
        
        var u8: UInt8 = 0;
        var u16: UInt16 = 0;
        var u32: UInt32 = 0;
        rrData.append(UnsafeBufferPointer(start: &u8, count: 1));
        u16 = UInt16(kDNSServiceType_SRV).bigEndian;
        rrData.append(UnsafeBufferPointer(start: &u16, count: 1));
        u16 = UInt16(kDNSServiceClass_IN).bigEndian;
        rrData.append(UnsafeBufferPointer(start: &u16, count: 1));
        u32 = UInt32(666).bigEndian;
        rrData.append(UnsafeBufferPointer(start: &u32, count: 1));
        u16 = rdlen.bigEndian;
        rrData.append(UnsafeBufferPointer(start: &u16, count: 1));
        rrData.append(rdata, count: Int(rdlen));
        
        guard let (port, weight, priority, target) = rrData.withUnsafeBytes({ (bytes) -> (Int, Int, Int, String)? in
            if let rr: UnsafeMutablePointer<dns_resource_record_t> = dns_parse_resource_record(bytes.baseAddress!.assumingMemoryBound(to: Int8.self), UInt32(rrData.count)) {
                defer {
                    dns_free_resource_record(rr);
                }
                if let target = String(cString: rr.pointee.data.SRV.pointee.target, encoding: .ascii) {
                    let priority = rr.pointee.data.SRV.pointee.priority;
                    let weight = rr.pointee.data.SRV.pointee.weight;
                    let port = rr.pointee.data.SRV.pointee.port;
                    
                    return (Int(port), Int(weight), Int(priority), target);
                }
            }
            return nil;
        }) else {
            return nil;
        }
        
        self.init(port: port, weight: weight, priority: priority, target: target, directTls: false);
    }
    
    public init(port:Int, weight:Int, priority:Int, target:String, directTls: Bool, invalid: Date? = nil) {
        self.port = port;
        self.weight = weight;
        self.priority = priority;
        self.target = target;
        self.directTls = directTls;
        self.invalid = invalid;
    }
    
    open func with(directTLS: Bool) -> XMPPSrvRecord {
        return XMPPSrvRecord(port: port, weight: weight, priority: priority, target: target, directTls: directTLS);
    }
    
    open func markAsInvalid(for period: TimeInterval) {
        self.invalid = Date().addingTimeInterval(period);
    }
}

open class XMPPSrvResult: Codable {
    
    public let domain: String;
    fileprivate(set) var records: [XMPPSrvRecord];
    public var hasValid: Bool {
        return records.firstIndex(where: { (rec) -> Bool in
            return rec.isValid == true;
        }) != nil;
    }
    
    public init(domain: String, records: [XMPPSrvRecord]) {
        self.domain = domain;
        self.records = records;
    }
    
    open func record() -> XMPPSrvRecord? {
        return records.first { (rec) -> Bool in
            return rec.isValid;
        }
    }
    
    open func update(fromQuery records: [XMPPSrvRecord]) -> Bool {
        var tmp = self.records;
        var changed: Bool = false;
        let count = tmp.count;
        tmp = tmp.filter { (rec) -> Bool in
            return records.contains(rec);
        };
        changed = changed || (count != tmp.count);
        
        if !tmp.contains(where: { rec in rec.invalid == nil }) {
            tmp.forEach { (rec) in
                rec.invalid = nil;
            }
            changed = true;
        }
        
        records.forEach { (rec) in
            guard let found = tmp.first(where: { (oldRec) -> Bool in
                return oldRec == rec;
            }) else {
                changed = true;
                tmp.append(rec);
                return;
            }
            if rec.invalid != nil {
                found.invalid = rec.invalid;
                changed = true;
            }
        }
//        tmp.append(contentsOf: records.filter({ (rec) -> Bool in
//            return !tmp.contains(rec);
//        }));
//        changed = changed || (count != tmp.count);
 
        self.records = tmp.sorted(by: { (a,b) -> Bool in
            if (a.priority < b.priority) {
                return true;
            } else if (a.priority > b.priority) {
                return false;
            } else {
                return a.weight > b.weight;
            }
        });
        return changed;
    }
    
    func markAsInvalid(record: XMPPSrvRecord, for period: TimeInterval) {
        guard let found = self.records.first(where: { (rec) -> Bool in
            return rec == record;
        }) else {
            return;
        }
        found.markAsInvalid(for: period);
    }
}
