//
// ScramMechanism.swift
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
 Mechanism implements SASL SCRAM authentication mechanism
 */
open class ScramMechanism: SaslMechanism {

    public static let SCRAM_SALTED_PASSWORD_CACHE = "SCRAM_SALTED_PASSWORD_CACHE";
    
    fileprivate static let ALPHABET = [Character]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    
    fileprivate static let SERVER_FIRST_MESSAGE = try! NSRegularExpression(pattern: "^(m=[^\\000=]+,)?r=([\\x21-\\x2B\\x2D-\\x7E]+),s=([a-zA-Z0-9/+=]+),i=(\\d+)(?:,.*)?$", options: NSRegularExpression.Options(rawValue: 0));
    fileprivate static let SERVER_LAST_MESSAGE = try! NSRegularExpression(pattern: "^(?:e=([^,]+)|v=([a-zA-Z0-9/+=]+)(?:,.*)?)$", options: NSRegularExpression.Options(rawValue: 0));

    public static func ScramSha256() -> ScramMechanism {
        var data = "Client Key".data(using: String.Encoding.utf8)!;
        var clientKey = Array<UInt8>(repeating: 0, count: data.count);
        (data as NSData).getBytes(&clientKey, length: data.count);
        data = "Server Key".data(using: String.Encoding.utf8)!;
        var serverKey = Array<UInt8>(repeating: 0, count: data.count);
        (data as NSData).getBytes(&serverKey, length: data.count);
        return ScramMechanism(mechanismName: "SCRAM-SHA-256", algorithm: Digest.sha256, clientKey: clientKey, serverKey: serverKey);
    }

    public static func ScramSha1() -> ScramMechanism {
        var data = "Client Key".data(using: String.Encoding.utf8)!;
        var clientKey = Array<UInt8>(repeating: 0, count: data.count);
        (data as NSData).getBytes(&clientKey, length: data.count);
        data = "Server Key".data(using: String.Encoding.utf8)!;
        var serverKey = Array<UInt8>(repeating: 0, count: data.count);
        (data as NSData).getBytes(&serverKey, length: data.count);
        return ScramMechanism(mechanismName: "SCRAM-SHA-1", algorithm: Digest.sha1, clientKey: clientKey, serverKey: serverKey);
    }
    
    public static func setSaltedPasswordCache(_ cache: ScramSaltedPasswordCacheProtocol?, sessionObject: SessionObject) {
        sessionObject.setUserProperty(ScramMechanism.SCRAM_SALTED_PASSWORD_CACHE, value: cache);
    }
    
    /// Name of mechanism
    public let name: String;
    public private(set) var status: SaslMechanismStatus = .new;
    
    fileprivate let algorithm: Digest;
    
    fileprivate let clientKeyData: [UInt8];
    fileprivate let serverKeyData: [UInt8];
    
    public init(mechanismName: String, algorithm: Digest, clientKey: [UInt8], serverKey: [UInt8]) {
        self.name = mechanismName;
        self.algorithm = algorithm;
        self.clientKeyData = clientKey;
        self.serverKeyData = serverKey;
    }
    
    open func evaluateChallenge(_ input: String?, sessionObject: SessionObject) throws -> String? {
        guard status != .completed else {
            guard input == nil else {
                throw ClientSaslException.genericError(msg: "Client in illegal state - already authorized!");
            }
            return nil;
        }
        
        let data = getData();
    
        let saltedPasswordCache: ScramSaltedPasswordCacheProtocol? = sessionObject.getProperty(ScramMechanism.SCRAM_SALTED_PASSWORD_CACHE);
        
        switch data.stage {
        case 0:
            data.conce = randomString();
            
            var sb = "n,";
            sb += ",";
            data.cb = sb;
            
            data.clientFirstMessageBare = "n=" + sessionObject.userBareJid!.localPart! + "," + "r=" + data.conce!;
            data.stage += 1;
            
            return (sb + data.clientFirstMessageBare!).data(using: String.Encoding.utf8)?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0));
        case 1:
            guard input != nil else {
                throw ClientSaslException.badChallenge(msg: "Received empty challenge!");
            }
            let msgBytes = Foundation.Data(base64Encoded: input!, options: NSData.Base64DecodingOptions(rawValue: 0));
            
            guard msgBytes != nil else {
                throw ClientSaslException.badChallenge(msg: "Failed to decode challenge!");
            }
            let msg = String(data: msgBytes!, encoding: String.Encoding.utf8);
            let r = ScramMechanism.SERVER_FIRST_MESSAGE.matches(in: msg!, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: NSMakeRange(0, msg!.count));
            
            guard r.count == 1 && r[0].numberOfRanges >= 5  else {
                throw ClientSaslException.badChallenge(msg: "Failed to parse challenge!");
            }
            let msgNS = msg! as NSString;
            let m = r[0];
            _ = groupPartOfString(m, group: 1, str: msgNS);
            guard let nonce = groupPartOfString(m, group: 2, str: msgNS) else {
                throw ClientSaslException.badChallenge(msg: "Missing nonce");
            }

            guard let saltStr = groupPartOfString(m, group: 3, str: msgNS) else {
                throw ClientSaslException.badChallenge(msg: "Missing salt");
            }

            guard let salt = Foundation.Data(base64Encoded: saltStr, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
                throw ClientSaslException.badChallenge(msg: "Invalid encoding of salt");
            }
            guard let iterations = Int(groupPartOfString(m, group: 4, str: msgNS) ?? "") else {
                throw ClientSaslException.badChallenge(msg: "Invalid number of iterations");
            }

            guard nonce.hasPrefix(data.conce!) else {
                throw ClientSaslException.wrongNonce;
            }

            let callback:CredentialsCallback = sessionObject.getProperty(AuthModule.CREDENTIALS_CALLBACK) ?? DefaultCredentialsCallback(sessionObject: sessionObject);

            let c = data.cb.data(using: String.Encoding.utf8)?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0));
            
            var clientFinalMessage = "c=" + c! + "," + "r=" + nonce;
            let part = "," + msg! + ",";
            data.authMessage = data.clientFirstMessageBare! + part + clientFinalMessage;
            
            let saltedCacheId = saltedPasswordCache?.generateId(algorithm: algorithm, salt: salt, iterations: iterations);
            if saltedCacheId != nil {
                data.saltedPassword = saltedPasswordCache?.getSaltedPassword(for: sessionObject, id: saltedCacheId!);
            }
            if data.saltedPassword == nil {
                data.saltedCacheId = saltedCacheId;
                data.saltedPassword = hi(password: normalize(callback.getCredential()), salt: salt, iterations: iterations);
            }
            var clientKeyData = self.clientKeyData;
            var clientKey = algorithm.hmac(key: &data.saltedPassword!, data: &clientKeyData);
            var storedKey = algorithm.digest(bytes: &clientKey, length: clientKey.count);
            
            var clientSignature = algorithm.hmac(key: &storedKey, data: data.authMessage!.data(using: String.Encoding.utf8)!);
            var clientProof = xor(clientKey, &clientSignature);
            
            clientFinalMessage += "," + "p=" + Foundation.Data(bytes: &clientProof, count: clientProof.count).base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0));

            data.stage += 1;
            status = .completedExpected;
            return clientFinalMessage.data(using: String.Encoding.utf8)?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0));
        case 2:
            guard input != nil else {
                saltedPasswordCache?.clearCache(for: sessionObject);
                throw ClientSaslException.badChallenge(msg: "Received empty challenge!");
            }

            let msgBytes = Foundation.Data(base64Encoded: input!, options: NSData.Base64DecodingOptions(rawValue: 0));
            
            guard msgBytes != nil else {
                saltedPasswordCache?.clearCache(for: sessionObject);
                throw ClientSaslException.badChallenge(msg: "Failed to decode challenge!");
            }
            let msg = String(data: msgBytes!, encoding: String.Encoding.utf8);
            let r = ScramMechanism.SERVER_LAST_MESSAGE.matches(in: msg!, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: NSMakeRange(0, msg!.count));
            
            guard r.count == 1 && r[0].numberOfRanges >= 3  else {
                saltedPasswordCache?.clearCache(for: sessionObject);
                throw ClientSaslException.badChallenge(msg: "Failed to parse challenge!");
            }
            let msgNS = msg! as NSString;
            let m = r[0];
            _ = groupPartOfString(m, group: 1, str: msgNS);
            guard let v = groupPartOfString(m, group: 2, str: msgNS) else {
                saltedPasswordCache?.clearCache(for: sessionObject);
                throw ClientSaslException.badChallenge(msg: "Invalid value of 'v'");
            }
            
            var serverKeyData = self.serverKeyData;
            var serverKey = algorithm.hmac(key: &data.saltedPassword!, data: &serverKeyData);
            var serverSignature = algorithm.hmac(key: &serverKey, data: data.authMessage!.data(using: String.Encoding.utf8)!);
            
            let value = Foundation.Data(base64Encoded: v, options: NSData.Base64DecodingOptions(rawValue: 0));
            guard value != nil && (value! == Foundation.Data(bytes: &serverSignature, count: serverSignature.count)) else {
                saltedPasswordCache?.clearCache(for: sessionObject);
                throw ClientSaslException.invalidServerSignature;
            }
            
            data.stage += 1;
            if let saltedCacheId = data.saltedCacheId, let saltedPassword = data.saltedPassword {
                saltedPasswordCache?.store(for: sessionObject, id: saltedCacheId, saltedPassword: saltedPassword);
            }
            status = .completed;
            
            // releasing data object
            self.saslData = nil;
            return nil;
        default:
            guard status == .completed && input == nil else {
                saltedPasswordCache?.clearCache(for: sessionObject);
                throw ClientSaslException.genericError(msg: "Client in illegal state! stage = \(data.stage)");
            }
            // let's assume this is ok as session is authenticated
            return nil;
        }
        
    }
    
    open func isAllowedToUse(_ sessionObject: SessionObject) -> Bool {
        return sessionObject.hasProperty(SessionObject.PASSWORD)
            && sessionObject.hasProperty(SessionObject.USER_BARE_JID);
    }
    
    func hi(password: Foundation.Data, salt: Foundation.Data, iterations: Int) -> [UInt8] {
        let k = password;
        var z = Array<UInt8>(repeating: 0, count: salt.count);
        (salt as NSData).getBytes(&z, length: salt.count);
        z.append(contentsOf: [ 0, 0, 0, 1]);
        
        var u = algorithm.hmac(keyData: k, data: &z);
        var result = u;
        
        for _ in  1..<iterations {
            u = algorithm.hmac(keyData: k, data: &u);
            for j in 0..<u.count {
                result[j] ^= u[j];
            }
        }
        
        return result;
    }
    
    func normalize(_ str: String) -> Foundation.Data {
        return str.data(using: String.Encoding.utf8)!;
    }
    
    private var saslData: Data?;
    
    func getData() -> Data {
        guard let data = saslData else {
            let data = Data();
            self.saslData = data;
            return data;
        }
        return data;
    }
    
    func randomString() -> String {
        let length = 20;
        //let x = ScramMechanism.ALPHABET.count;
        var buffer = Array(repeating: "\0".first!, count: length);
        for i in 0..<length {
            let r = Int(arc4random_uniform(UInt32(length)));
            let c = ScramMechanism.ALPHABET[r];
            buffer[i] = c;
        }
        return String(buffer);
    }
    
    func xor (_ a: [UInt8], _ b: inout [UInt8]) -> [UInt8] {
        var r = a;
        for i in 0..<r.count {
            r[i] ^= b[i];
        }
        return r;
    }
    
    func groupPartOfString(_ m: NSTextCheckingResult, group: Int, str: NSString) -> String? {
        guard group < m.numberOfRanges else {
            return nil;
        }
        
        let r = m.range(at: group);
        guard r.length != 0 else {
            return "";
        }
        
        return str.substring(with: r);
    }
    
    class Data {
        var authMessage: String?;
        var cb: String = "n,";
        var clientFirstMessageBare: String?;
        var conce: String?;
        var saltedCacheId: String?;
        var saltedPassword: [UInt8]?;
        var stage: Int = 0;
    }
}
