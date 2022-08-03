//
// SslCertificateValidator.swift
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
import CryptoKit

open class SslCertificateValidator {
        
    public static func validateSslCertificate(domain: String, fingerprint acceptedFingerprint: SSLCertificateInfo.Fingerprint, trust: SecTrust) -> Bool {
        let policy = SecPolicyCreateSSL(false, domain as CFString?);
        var secTrustResultType = SecTrustResultType.invalid;
        var error: CFError?;
        SecTrustSetPolicies(trust, policy);
        _ = SecTrustEvaluateWithError(trust, &error);
        SecTrustGetTrustResult(trust, &secTrustResultType);
        
        var valid = (secTrustResultType == SecTrustResultType.proceed || secTrustResultType == SecTrustResultType.unspecified);
        if !valid {
            let certCount = SecTrustGetCertificateCount(trust);
            
            if certCount > 0 {
                let cert = SecTrustGetCertificateAtIndex(trust, 0);
                valid = acceptedFingerprint.matches(certificate: cert!);
            }
            else {
                valid = false;
            }
        }
        return valid;
    }
    
}

public enum SSLCertificateValidation {
    case `default`
    case fingerprint(SSLCertificateInfo.Fingerprint)
    case customValidator((SecTrust)->Bool)
}
