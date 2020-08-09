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

open class SslCertificateValidator {
    
    public static let ACCEPTED_SSL_CERTIFICATE_FINGERPRINT = "SslCertificateValidator#AcceptedFingerprint";
 
    public static func registerSslCertificateValidator(_ sessionObject: SessionObject) {
        sessionObject.setUserProperty(SocketConnector.SSL_CERTIFICATE_VALIDATOR, value: SslCertificateValidator.validateSslCertificate);
    }
    
    public static func setAcceptedSslCertificate(_ sessionObject: SessionObject, fingerprint: String?) {
        sessionObject.setUserProperty(SslCertificateValidator.ACCEPTED_SSL_CERTIFICATE_FINGERPRINT, value: fingerprint);
    }
    
    public static func validateSslCertificate(_ sessionObject: SessionObject, trust: SecTrust) -> Bool {
        let policy = SecPolicyCreateSSL(false, sessionObject.userBareJid?.domain as CFString?);
        var secTrustResultType = SecTrustResultType.invalid;
        SecTrustSetPolicies(trust, policy);
        SecTrustEvaluate(trust, &secTrustResultType);
        
        var valid = (secTrustResultType == SecTrustResultType.proceed || secTrustResultType == SecTrustResultType.unspecified);
        if !valid {
            let certCount = SecTrustGetCertificateCount(trust);
            
            if certCount > 0 {
                let cert = SecTrustGetCertificateAtIndex(trust, 0);
                let fingerprint = SslCertificateInfo.calculateSha1Fingerprint(certificate: cert!);
                let acceptedFingerprint: String? = sessionObject.getProperty(SslCertificateValidator.ACCEPTED_SSL_CERTIFICATE_FINGERPRINT);
                valid = fingerprint == acceptedFingerprint;
            }
            else {
                valid = false;
            }
        }
        return valid;
    }
    
}
