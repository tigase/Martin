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
import CryptoKit

public protocol ScramAlgorithm {
    
    var name: String { get }
    
    func digest<D: DataProtocol>(data: D) -> Data;
    func hmac<K: ContiguousBytes, D: DataProtocol>(key: K, data: D) -> Data;
    
}

public protocol ScramAlgorithmBase: ScramAlgorithm {
    
    associatedtype Hash: HashFunction
    
}

extension ScramAlgorithmBase {
        
    public func digest<D: DataProtocol>(data: D) -> Data {
        return Data(Hash.hash(data: data));
    }
    
    public func hmac<K: ContiguousBytes, D: DataProtocol>(key: K, data: D) -> Data {
        return Data(HMAC<Hash>.authenticationCode(for: data, using: .init(data: key)));
    }
    
}

public struct ScramSHA1: ScramAlgorithmBase {
    
    public typealias Hash = Insecure.SHA1;
    
    public var name: String {
        return "SHA1";
    }
    
}

public struct ScramSHA256: ScramAlgorithmBase {
    
    public typealias Hash = SHA256;
    
    public var name: String {
        return "SHA256";
    }
    
}


/**
 Mechanism implements SASL SCRAM authentication mechanism
 */
open class ScramMechanism: SaslMechanism {

    public static let SCRAM_SALTED_PASSWORD_CACHE = "SCRAM_SALTED_PASSWORD_CACHE";
    
    fileprivate static let ALPHABET = [Character]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    
    fileprivate static let SERVER_FIRST_MESSAGE = try! NSRegularExpression(pattern: "^(m=[^\\000=]+,)?r=([\\x21-\\x2B\\x2D-\\x7E]+),s=([a-zA-Z0-9/+=]+),i=(\\d+)(?:,.*)?$", options: NSRegularExpression.Options(rawValue: 0));
    fileprivate static let SERVER_LAST_MESSAGE = try! NSRegularExpression(pattern: "^(?:e=([^,]+)|v=([a-zA-Z0-9/+=]+)(?:,.*)?)$", options: NSRegularExpression.Options(rawValue: 0));

    public static func ScramSha256() -> ScramMechanism {
        let clientKey = "Client Key".data(using: .utf8)!;
        let serverKey = "Server Key".data(using: .utf8)!;
        return ScramMechanism(mechanismName: "SCRAM-SHA-256", algorithm: ScramSHA256(), clientKey: clientKey, serverKey: serverKey);
    }

    public static func ScramSha1() -> ScramMechanism {
        let clientKey = "Client Key".data(using: .utf8)!;
        let serverKey = "Server Key".data(using: .utf8)!;
        return ScramMechanism(mechanismName: "SCRAM-SHA-1", algorithm: ScramSHA1(), clientKey: clientKey, serverKey: serverKey);
    }
        
    /// Name of mechanism
    public let name: String;
    public private(set) var status: SaslMechanismStatus = .new {
        didSet {
            if status == .new {
                saslData = nil;
            }
        }
    }
    
    fileprivate let algorithm: ScramAlgorithm;
    
    fileprivate let clientKeyData: Data;
    fileprivate let serverKeyData: Data;
    private var saslData: SaslData?;
    
    public init(mechanismName: String, algorithm: ScramAlgorithm, clientKey: Data, serverKey: Data) {
        self.name = mechanismName;
        self.algorithm = algorithm;
        self.clientKeyData = clientKey;
        self.serverKeyData = serverKey;
    }
    
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.stream) {
            status = .new;
        }
    }

    open func evaluateChallenge(_ input: String?, context: Context) throws -> String? {
        guard status != .completed else {
            guard input == nil else {
                throw ClientSaslException.genericError(msg: "Client in illegal state - already authorized!");
            }
            return nil;
        }
        
        let data = getData();
    
        switch context.connectionConfiguration.credentials {
        case .password(let password, let authenticationName, let saltedPasswordCache):
            switch data.stage {
            case 0:
                data.conce = randomString();
                
                var sb = "n,";
                sb += ",";
                data.cb = sb;
                
                data.clientFirstMessageBare = "n=" + context.userBareJid.localPart! + "," + "r=" + data.conce!;
                data.stage += 1;
                
                return (sb + data.clientFirstMessageBare!).data(using: .utf8)?.base64EncodedString();
            case 1:
                guard let input = input else {
                    throw ClientSaslException.badChallenge(msg: "Received empty challenge!");
                }
                
                guard let msgBytes = Data(base64Encoded: input) else {
                    throw ClientSaslException.badChallenge(msg: "Failed to decode challenge!");
                }
                guard let msg = String(data: msgBytes, encoding: .utf8) else {
                    throw ClientSaslException.badChallenge(msg: "Failed to parse challenge!");
                }
                let r = ScramMechanism.SERVER_FIRST_MESSAGE.matches(in: msg, options: .withoutAnchoringBounds, range: NSMakeRange(0, msg.count));
                
                guard r.count == 1 && r[0].numberOfRanges >= 5  else {
                    throw ClientSaslException.badChallenge(msg: "Failed to parse challenge!");
                }
                let msgNS = msg as NSString;
                let m = r[0];
                _ = groupPartOfString(m, group: 1, str: msgNS);
                guard let nonce = groupPartOfString(m, group: 2, str: msgNS) else {
                    throw ClientSaslException.badChallenge(msg: "Missing nonce");
                }

                guard let saltStr = groupPartOfString(m, group: 3, str: msgNS) else {
                    throw ClientSaslException.badChallenge(msg: "Missing salt");
                }

                guard let salt = Data(base64Encoded: saltStr) else {
                    throw ClientSaslException.badChallenge(msg: "Invalid encoding of salt");
                }
                guard let iterations = Int(groupPartOfString(m, group: 4, str: msgNS) ?? "") else {
                    throw ClientSaslException.badChallenge(msg: "Invalid number of iterations");
                }

                guard nonce.hasPrefix(data.conce!) else {
                    throw ClientSaslException.wrongNonce;
                }

                let c = data.cb.data(using: .utf8)?.base64EncodedString();
                
                var clientFinalMessage = "c=\(c!),r=\(nonce)";
                let part = ",\(msg),";
                data.authMessage = data.clientFirstMessageBare! + part + clientFinalMessage;
                
                let saltedCacheId = saltedPasswordCache?.generateId(algorithm: algorithm, salt: salt, iterations: iterations);
                if saltedCacheId != nil {
                    data.saltedPassword = saltedPasswordCache?.getSaltedPassword(for: context, id: saltedCacheId!);
                }
                if data.saltedPassword == nil {
                    data.saltedCacheId = saltedCacheId;
                    data.saltedPassword = hi(password: normalize(password), salt: salt, iterations: iterations);
                }
                let clientKey = algorithm.hmac(key: data.saltedPassword!, data: clientKeyData);
                let storedKey = algorithm.digest(data: clientKey);
                
                let clientSignature = algorithm.hmac(key: storedKey, data: data.authMessage!.data(using: .utf8)!);
                let clientProof = xor(clientKey, clientSignature);
                
                clientFinalMessage += ",p=\(clientProof.base64EncodedString())";

                data.stage += 1;
                status = .completedExpected;
                return clientFinalMessage.data(using: .utf8)?.base64EncodedString();
            case 2:
                guard let input = input else {
                    saltedPasswordCache?.clearCache(for: context);
                    throw ClientSaslException.badChallenge(msg: "Received empty challenge!");
                }
                
                guard let msgBytes = Data(base64Encoded: input) else {
                    saltedPasswordCache?.clearCache(for: context);
                    throw ClientSaslException.badChallenge(msg: "Failed to decode challenge!");
                }
                guard let msg = String(data: msgBytes, encoding: .utf8) else {
                    throw ClientSaslException.badChallenge(msg: "Failed to parse challenge!");
                }
                
                let r = ScramMechanism.SERVER_LAST_MESSAGE.matches(in: msg, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: NSMakeRange(0, msg.count));
                
                guard r.count == 1 && r[0].numberOfRanges >= 3  else {
                    saltedPasswordCache?.clearCache(for: context);
                    throw ClientSaslException.badChallenge(msg: "Failed to parse challenge!");
                }
                let msgNS = msg as NSString;
                let m = r[0];
                _ = groupPartOfString(m, group: 1, str: msgNS);
                guard let v = groupPartOfString(m, group: 2, str: msgNS) else {
                    saltedPasswordCache?.clearCache(for: context);
                    throw ClientSaslException.badChallenge(msg: "Invalid value of 'v'");
                }
                
                let serverKeyData = self.serverKeyData;
                let serverKey = algorithm.hmac(key: data.saltedPassword!, data: serverKeyData);
                let serverSignature = algorithm.hmac(key: serverKey, data: data.authMessage!.data(using: .utf8)!);
                
                guard let value = Data(base64Encoded: v), value == serverSignature else {
                    saltedPasswordCache?.clearCache(for: context);
                    throw ClientSaslException.invalidServerSignature;
                }
                
                data.stage += 1;
                if let saltedCacheId = data.saltedCacheId, let saltedPassword = data.saltedPassword {
                    saltedPasswordCache?.store(for: context, id: saltedCacheId, saltedPassword: saltedPassword);
                }
                status = .completed;
                
                // releasing data object
                self.saslData = nil;
                return nil;
            default:
                guard status == .completed && input == nil else {
                    saltedPasswordCache?.clearCache(for: context);
                    throw ClientSaslException.genericError(msg: "Client in illegal state! stage = \(data.stage)");
                }
                // let's assume this is ok as session is authenticated
                return nil;
            }

        default:
            throw ClientSaslException.genericError(msg: "Invalid credentials type for authorization!");
        }
                
    }
    
    open func isAllowedToUse(_ context: Context) -> Bool {
        switch context.connectionConfiguration.credentials {
        case .password(_, _, _):
            return true;
        default:
            return false;
        }
    }
    
    func hi(password: Data, salt: Data, iterations: Int) -> Data {
        let k = password;
        var z = salt;
        z.append(contentsOf: [ 0, 0, 0, 1])
        
        var u = algorithm.hmac(key: k, data: z);
        var result = u;
        
        for _ in  1..<iterations {
            u = algorithm.hmac(key: k, data: u);
            for j in 0..<u.count {
                result[j] ^= u[j];
            }
        }
        
        return result;
    }
    
    func normalize(_ str: String) -> Data {
        return str.data(using: .utf8)!;
    }
    
    func getData() -> SaslData {
        guard let data = saslData else {
            let data = SaslData();
            self.saslData = data;
            return data;
        }
        return data;
    }
    
    func randomString() -> String {
        let length = 20;
        var buffer = Array(repeating: "\0".first!, count: length);
        for i in 0..<length {
            let r = Int(arc4random_uniform(UInt32(length)));
            let c = ScramMechanism.ALPHABET[r];
            buffer[i] = c;
        }
        return String(buffer);
    }
    
    func xor (_ a: Data, _ b: Data) -> Data {
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
    
    class SaslData {
        var authMessage: String?;
        var cb: String = "n,";
        var clientFirstMessageBare: String?;
        var conce: String?;
        var saltedCacheId: String?;
        var saltedPassword: Data?;
        var stage: Int = 0;
    }
}
