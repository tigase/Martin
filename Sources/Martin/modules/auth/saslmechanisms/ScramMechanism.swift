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

public typealias ScramSha1Mechanism = ScramMechanism<HashAlgorithms.SHA1>
public typealias ScramSha256Mechanism = ScramMechanism<HashAlgorithms.SHA256>

public protocol ScramMechanismProtocol: SaslMechanism {
    
    var supportsChannelBinding: Bool { get }
    var storeSaltedPassword: Bool { get set }
    
}

/**
 Mechanism implements SASL SCRAM authentication mechanism
 */
open class ScramMechanism<Hash: HashAlgorithm>: Sasl2UpgradableMechanism {
    
    private let ALPHABET = [Character]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    
    private let SERVER_FIRST_MESSAGE = try! NSRegularExpression(pattern: "^(m=[^\\000=]+,)?r=([\\x21-\\x2B\\x2D-\\x7E]+),s=([a-zA-Z0-9/+=]+),i=(\\d+)(?:,.*)?$", options: NSRegularExpression.Options(rawValue: 0));
    private let SERVER_LAST_MESSAGE = try! NSRegularExpression(pattern: "^(?:e=([^,]+)|v=([a-zA-Z0-9/+=]+)(?:,.*)?)$", options: NSRegularExpression.Options(rawValue: 0));

    private let CLIENT_KEY_DATA = "Client Key".data(using: .utf8)!;
    private let SERVER_KEY_DATA = "Server Key".data(using: .utf8)!;
    
    private let SASL2_UPGRADE_0_XMLNS = "urn:xmpp:scram-upgrade:0";
    
    /// Name of mechanism
    public let name: String;
    public private(set) var status: SaslMechanismStatus = .new {
        didSet {
            if status == .new {
                saslData = nil;
            }
        }
    }
    
    private var saslData: SaslData?;
    private var serverBindings: [ChannelBinding] = [];
    
    public let supportsChannelBinding: Bool;
    public var storeSaltedPassword = false;
    
    public init(withChannelBinding supportsChannelBinding: Bool) {
        self.name = "SCRAM-\(Hash.name)\(supportsChannelBinding ? "-PLUS" : "")";
        self.supportsChannelBinding = supportsChannelBinding;
    }
    
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.stream) {
            status = .new;
            serverBindings = [];
        }
    }
    
    public func streamFeaturesChanged(_ streamFeatures: StreamFeatures) {
        serverBindings = streamFeatures.get(.saslChannelBinding).flatMap({ ChannelBinding.parse(element: $0) }) ?? [];
    }
    
    private func selectChannelBinding(context: Context) -> ChannelBinding? {
        let localBindings = (context as? XMPPClient)?.connector?.supportedChannelBindings ?? [];
        for binding in localBindings {
            if serverBindings.contains(binding) {
                return binding;
            }
        }
        return nil;
    }

    open func evaluateChallenge(_ input: String?, context: Context) throws -> String? {
        guard status != .completed else {
            guard input == nil else {
                throw ClientSaslException.genericError(msg: "Client in illegal state - already authorized!");
            }
            return nil;
        }
        
        let data = getData();
            
        switch data.stage {
        case 0:
            data.conce = randomString();
                
            var sb = "";
                
            if supportsChannelBinding, let binding = selectChannelBinding(context: context) {
                sb = "p=\(binding.rawValue),";
                do {
                    data.channelBindingData = try (context as? XMPPClient)?.connector?.channelBindingData(type: binding);
                } catch let e as XMPPError {
                    guard e.condition == .feature_not_implemented else {
                        throw e;
                    }
                    sb = "n,";
                }
            } else {
                sb = "n,";
            }
            sb += ",";
            data.cb = sb;
                
            data.clientFirstMessageBare = "n=" + context.userBareJid.localPart! + "," + "r=" + data.conce!;
            data.stage += 1;
            self.status = .inProgress;
                
            return (sb + data.clientFirstMessageBare!).data(using: .utf8)?.base64EncodedString();
        case 1:
            guard let input = input else {
                throw ClientSaslException.badChallenge(msg: "Received empty challenge!");
            }
                
            guard let msgBytes = Data(base64Encoded: input), let msg = String(data: msgBytes, encoding: .utf8) else {
                throw ClientSaslException.badChallenge(msg: "Failed to decode challenge!");
            }
            
            let r = SERVER_FIRST_MESSAGE.matches(in: msg, options: .withoutAnchoringBounds, range: NSMakeRange(0, msg.count));
                
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

            let c = ((data.cb.data(using: .utf8)!) + (data.channelBindingData ?? Data())).base64EncodedString();
                
            var clientFinalMessage = "c=\(c),r=\(nonce)";
            let part = ",\(msg),";
            data.authMessage = data.clientFirstMessageBare! + part + clientFinalMessage;
            data.saltedPassword = try prepareSaltedPassword(context: context, salt: salt, iterations: iterations);

            let clientKey = Hash.hmac(key: data.saltedPassword!, data: CLIENT_KEY_DATA);
            let storedKey = Hash.digest(data: clientKey);
                
            let clientSignature = Hash.hmac(key: storedKey, data: data.authMessage!.data(using: .utf8)!);
            let clientProof = xor(clientKey, clientSignature);
                
            clientFinalMessage += ",p=\(clientProof.base64EncodedString())";

            data.stage += 1;
            status = .completedExpected;
            return clientFinalMessage.data(using: .utf8)?.base64EncodedString();
        case 2:
            do {
                guard let input = input else {
                    throw ClientSaslException.badChallenge(msg: "Received empty challenge!");
                }
                
                guard let msgBytes = Data(base64Encoded: input), let msg = String(data: msgBytes, encoding: .utf8) else {
                    throw ClientSaslException.badChallenge(msg: "Failed to decode challenge!");
                }
                
                let r = SERVER_LAST_MESSAGE.matches(in: msg, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: NSMakeRange(0, msg.count));
                
                guard r.count == 1 && r[0].numberOfRanges >= 3  else {
                    throw ClientSaslException.badChallenge(msg: "Failed to parse challenge!");
                }
                let msgNS = msg as NSString;
                let m = r[0];
                _ = groupPartOfString(m, group: 1, str: msgNS);
                guard let v = groupPartOfString(m, group: 2, str: msgNS) else {
                    throw ClientSaslException.badChallenge(msg: "Invalid value of 'v'");
                }
                
                let serverKey = Hash.hmac(key: data.saltedPassword!, data: SERVER_KEY_DATA);
                let serverSignature = Hash.hmac(key: serverKey, data: data.authMessage!.data(using: .utf8)!);
                
                guard let value = Data(base64Encoded: v), value == serverSignature else {
                    throw ClientSaslException.invalidServerSignature;
                }
                
                data.stage += 1;
                status = .completed;
                
                // releasing data object
                self.saslData = nil;
                return nil;
            } catch {
                // clear cached salted password, to be sure..
                if storeSaltedPassword {
                    context.connectionConfiguration.credentials.saltedPassword = nil;
                }
                throw error;
            }
        default:
            guard status == .completed && input == nil else {
                throw ClientSaslException.genericError(msg: "Client in illegal state! stage = \(data.stage)");
            }
            // let's assume this is ok as session is authenticated
            return nil;
        }
    }
    
    private func prepareSaltedPassword(context: Context, salt: Data, iterations: Int) throws -> Data {
        let saltedId = SaltedPassword.generateId(mechanismName: name, salt: salt, iterations: iterations);
        if let saltedPassword = context.connectionConfiguration.credentials.saltedPassword, saltedPassword.id == saltedId {
            return saltedPassword.data;
        } else if let password = context.connectionConfiguration.credentials.password {
            let saltedPassword = hi(password: normalize(password), salt: salt, iterations: iterations);
            if storeSaltedPassword {
                context.connectionConfiguration.credentials.saltedPassword = SaltedPassword(id: saltedId, data: saltedPassword);
            }
            return saltedPassword;
        } else {
            throw SaslError(cause: .not_authorized, message: "Password and salted password were not specified");
        }
    }
    
    open func evaluateUpgrade(parameters: [Element], context: Context) async throws -> Element {
        guard let saltEl = parameters.first(where: { $0.name == "salt" && $0.xmlns == SASL2_UPGRADE_0_XMLNS}), let saltStr = saltEl.value, let salt = Data(base64Encoded: saltStr) else {
            throw XMPPError(condition: .bad_request, message: "Missing salt");
        }
        guard let iterationsStr = saltEl.attribute("iterations"), let iterations = Int(iterationsStr) else {
            throw XMPPError(condition: .bad_request, message: "Missing iterations");
        }
        guard let password = context.connectionConfiguration.credentials.password else {
            throw XMPPError(condition: .feature_not_implemented, message: "Cannot upgrade SCRAM - no password!");
        }
        let saltedPassword = hi(password: normalize(password), salt: salt, iterations: iterations);
        return Element(name: "hash", xmlns: SASL2_UPGRADE_0_XMLNS, cdata: saltedPassword.base64EncodedString());
    }
    
    open func isAllowedToUse(_ context: Context, features: StreamFeatures) -> Bool {
        guard context.connectionConfiguration.credentials.test({ $0.password != nil || $0.saltedPassword != nil}) else {
            return false;
        }
        if supportsChannelBinding {
            return !serverBindings.isEmpty;
        }
        return true;
    }
    
    func hi(password: Data, salt: Data, iterations: Int) -> Data {
        let k = password;
        var z = salt;
        z.append(contentsOf: [ 0, 0, 0, 1])
        
        var u = Hash.hmac(key: k, data: z);
        var result = u;
        
        for _ in  1..<iterations {
            u = Hash.hmac(key: k, data: u);
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
            let c = ALPHABET[r];
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
        var channelBindingData: Data?;
    }
}
