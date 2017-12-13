//
// SslCertificateInfo.swift
//
// TigaseSwift
// Copyright (C) 2017 "Tigase, Inc." <office@tigase.com>
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

open class SslCertificateInfo {

    open let details: Entry;
    open let issuer: Entry?;
    
    open static func calculateSha1Fingerprint(certificate: SecCertificate) -> String? {
        let data = SecCertificateCopyData(certificate) as Data;
        return Digest.sha1.digest(toHex: data);
    }
    
    public init(trust: SecTrust) {
        let certCount = SecTrustGetCertificateCount(trust);
        var details: Entry? = nil;
        var issuer: Entry? = nil;
        
        for i in 0..<certCount {
            let cert = SecTrustGetCertificateAtIndex(trust, i);
            let fingerprint = SslCertificateInfo.calculateSha1Fingerprint(certificate: cert!);
        
            // on first cert got 03469208e5d8e580f65799497d73b2d3098e8c8a
            // while openssl reports: SHA1 Fingerprint=03:46:92:08:E5:D8:E5:80:F6:57:99:49:7D:73:B2:D3:09:8E:8C:8A
            let summary = (SecCertificateCopySubjectSummary(cert!) as NSString?) as? String;
            print("cert", cert!, "SUMMARY:", summary, "fingerprint:", fingerprint);
            
            switch i {
            case 0:
                details = Entry(name: summary, fingerprintSha1: fingerprint);
            case 1:
                issuer = Entry(name: summary, fingerprintSha1: fingerprint);
            default:
                break;
            }
        }
        
        self.details = details!;
        self.issuer = issuer;
    }
        
    open class Entry {
    
        open let name: String?;
        open let fingerprintSha1: String?;
        
        public init(name: String?, fingerprintSha1: String?) {
            self.name = name;
            self.fingerprintSha1 = fingerprintSha1;
        }
        
    }
}
