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
public class ScramMechanism: Logger, SaslMechanism {

    public static let SCRAM_SASL_DATA_KEY = "SCRAM_SASL_DATA_KEY";
    
    private static let ALPHABET = [Character]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".characters);
    
    private static let SERVER_FIRST_MESSAGE = try! NSRegularExpression(pattern: "^(m=[^\\000=]+,)?r=([\\x21-\\x2B\\x2D-\\x7E]+),s=([a-zA-Z0-9/+=]+),i=(\\d+)(?:,.*)?$", options: NSRegularExpressionOptions(rawValue: 0));
    private static let SERVER_LAST_MESSAGE = try! NSRegularExpression(pattern: "^(?:e=([^,]+)|v=([a-zA-Z0-9/+=]+)(?:,.*)?)$", options: NSRegularExpressionOptions(rawValue: 0));
    
    public static func ScramSha1() -> ScramMechanism {
        var data = "Client Key".dataUsingEncoding(NSUTF8StringEncoding)!;
        var clientKey = Array<UInt8>(count: data.length, repeatedValue: 0);
        data.getBytes(&clientKey);
        data = "Server Key".dataUsingEncoding(NSUTF8StringEncoding)!;
        var serverKey = Array<UInt8>(count: data.length, repeatedValue: 0);
        data.getBytes(&serverKey);
        return ScramMechanism(mechanismName: "SCRAM-SHA-1", algorithm: Digest.SHA1, clientKey: clientKey, serverKey: serverKey);
    }
    
    /// Name of mechanism
    public let name: String;
    
    private let algorithm: Digest;
    
    private let clientKeyData: [UInt8];
    private let serverKeyData: [UInt8];
    
    public init(mechanismName: String, algorithm: Digest, clientKey: [UInt8], serverKey: [UInt8]) {
        self.name = mechanismName;
        self.algorithm = algorithm;
        self.clientKeyData = clientKey;
        self.serverKeyData = serverKey;
    }
    
    public func evaluateChallenge(input: String?, sessionObject: SessionObject) throws -> String? {
        guard !isComplete(sessionObject) else {
            guard input == nil else {
                throw ClientSaslException.GenericError(msg: "Client in illegal state - already authorized!");
            }
            return nil;
        }
        
        var data = getData(sessionObject);
    
        switch data.stage {
        case 0:
            data.conce = randomString();
            
            var sb = "n,";
            sb += ",";
            data.cb = sb;
            
            data.clientFirstMessageBare = "n=" + sessionObject.userBareJid!.localPart! + "," + "r=" + data.conce!;
            data.stage += 1;
            
            return (sb + data.clientFirstMessageBare!).dataUsingEncoding(NSUTF8StringEncoding)?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0));
        case 1:
            guard input != nil else {
                throw ClientSaslException.BadChallenge(msg: "Received empty challenge!");
            }
            let msgBytes = NSData(base64EncodedString: input!, options: NSDataBase64DecodingOptions(rawValue: 0));
            
            guard msgBytes != nil else {
                throw ClientSaslException.BadChallenge(msg: "Failed to decode challenge!");
            }
            let msg = String(data: msgBytes!, encoding: NSUTF8StringEncoding);
            let r = ScramMechanism.SERVER_FIRST_MESSAGE.matchesInString(msg!, options: NSMatchingOptions.WithoutAnchoringBounds, range: NSMakeRange(0, msg!.characters.count));
            
            guard r.count == 1 && r[0].numberOfRanges >= 5  else {
                throw ClientSaslException.BadChallenge(msg: "Failed to parse challenge!");
            }
            let msgNS = msg! as NSString;
            let m = r[0];
            let mext = groupPartOfString(m, group: 1, str: msgNS);
            guard let nonce = groupPartOfString(m, group: 2, str: msgNS) else {
                throw ClientSaslException.BadChallenge(msg: "Missing nonce");
            }

            guard let saltStr = groupPartOfString(m, group: 3, str: msgNS) else {
                throw ClientSaslException.BadChallenge(msg: "Missing salt");
            }

            guard let salt = NSData(base64EncodedString: saltStr, options: NSDataBase64DecodingOptions(rawValue: 0)) else {
                throw ClientSaslException.BadChallenge(msg: "Invalid encoding of salt");
            }
            guard let iterations = Int(groupPartOfString(m, group: 4, str: msgNS) ?? "") else {
                throw ClientSaslException.BadChallenge(msg: "Invalid number of iterations");
            }

            guard nonce.hasPrefix(data.conce!) else {
                throw ClientSaslException.WrongNonce;
            }

            let callback:CredentialsCallback = sessionObject.getProperty(AuthModule.CREDENTIALS_CALLBACK) ?? DefaultCredentialsCallback(sessionObject: sessionObject);

            let c = data.cb.dataUsingEncoding(NSUTF8StringEncoding)?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0));
            
            var clientFinalMessage = "c=" + c! + "," + "r=" + nonce;
            var part = "," + msg! + ",";
            data.authMessage = data.clientFirstMessageBare! + part + clientFinalMessage;
            
            data.saltedPassword = hi(normalize(callback.getCredential()), salt: salt, iterations: iterations);
            var clientKeyData = self.clientKeyData;
            var clientKey = algorithm.hmac(&data.saltedPassword, data: &clientKeyData);
            var storedKey = algorithm.digest(&clientKey, length: clientKey.count);
            
            var clientSignature = algorithm.hmac(&storedKey, data: data.authMessage!.dataUsingEncoding(NSUTF8StringEncoding)!);
            var clientProof = xor(clientKey, &clientSignature);
            
            clientFinalMessage += "," + "p=" + NSData(bytes: &clientProof, length: clientProof.count).base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0));

            data.stage += 1;
            return clientFinalMessage.dataUsingEncoding(NSUTF8StringEncoding)?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0));
        case 2:
            guard input != nil else {
                throw ClientSaslException.BadChallenge(msg: "Received empty challenge!");
            }

            let msgBytes = NSData(base64EncodedString: input!, options: NSDataBase64DecodingOptions(rawValue: 0));
            
            guard msgBytes != nil else {
                throw ClientSaslException.BadChallenge(msg: "Failed to decode challenge!");
            }
            let msg = String(data: msgBytes!, encoding: NSUTF8StringEncoding);
            let r = ScramMechanism.SERVER_LAST_MESSAGE.matchesInString(msg!, options: NSMatchingOptions.WithoutAnchoringBounds, range: NSMakeRange(0, msg!.characters.count));
            
            guard r.count == 1 && r[0].numberOfRanges >= 3  else {
                throw ClientSaslException.BadChallenge(msg: "Failed to parse challenge!");
            }
            let msgNS = msg! as NSString;
            let m = r[0];
            let e = groupPartOfString(m, group: 1, str: msgNS);
            guard let v = groupPartOfString(m, group: 2, str: msgNS) else {
                throw ClientSaslException.BadChallenge(msg: "Invalid value of 'v'");
            }
            
            var serverKeyData = self.serverKeyData;
            var serverKey = algorithm.hmac(&data.saltedPassword, data: &serverKeyData);
            var serverSignature = algorithm.hmac(&serverKey, data: data.authMessage!.dataUsingEncoding(NSUTF8StringEncoding)!);
            
            let value = NSData(base64EncodedString: v, options: NSDataBase64DecodingOptions(rawValue: 0));
            guard value != nil && value!.isEqualToData(NSData(bytes: &serverSignature, length: serverSignature.count)) else {
                throw ClientSaslException.InvalidServerSignature;
            }
            
            data.stage += 1;
            
            setComplete(sessionObject, completed: true);
            
            // releasing data object
            sessionObject.setProperty(ScramMechanism.SCRAM_SASL_DATA_KEY, value: nil);
            return nil;
        default:
            guard isComplete(sessionObject) && input == nil else {
                throw ClientSaslException.GenericError(msg: "Client in illegal state! stage = \(data.stage)");
            }
            // let's assume this is ok as session is authenticated
            return nil;
        }
        
    }
    
    public func isAllowedToUse(sessionObject: SessionObject) -> Bool {
        return sessionObject.hasProperty(SessionObject.PASSWORD)
            && sessionObject.hasProperty(SessionObject.USER_BARE_JID);
    }
    
    func hi(password: NSData, salt: NSData, iterations: Int) -> [UInt8] {
        var k = password;
        var z = Array<UInt8>(count: salt.length, repeatedValue: 0);
        salt.getBytes(&z, length: salt.length);
        z.appendContentsOf([ 0, 0, 0, 1]);
        
        var u = algorithm.hmac(k, data: &z);
        var result = u;
        
        for i in  1..<iterations {
            u = algorithm.hmac(k, data: &u);
            for j in 0..<u.count {
                result[j] ^= u[j];
            }
        }
        
        return result;
    }
    
    func normalize(str: String) -> NSData {
        return str.dataUsingEncoding(NSUTF8StringEncoding)!;
    }
    
    func getData(sessionObject: SessionObject) -> Data {
        var data: Data? = sessionObject.getProperty(ScramMechanism.SCRAM_SASL_DATA_KEY);
        if data == nil {
            data = Data();
            sessionObject.setProperty(ScramMechanism.SCRAM_SASL_DATA_KEY, value: data);
        }
        return data!;
    }
    
    func randomString() -> String {
        let length = 20;
        let x = ScramMechanism.ALPHABET.count;
        var buffer = Array(count: length, repeatedValue: "\0".characters.first!);
        for i in 0..<length {
            let r = Int(arc4random_uniform(UInt32(length)));
            let c = ScramMechanism.ALPHABET[r];
            buffer[i] = c;
        }
        return String(buffer);
    }
    
    func xor (a: [UInt8], inout _ b: [UInt8]) -> [UInt8] {
        var r = a;
        for i in 0..<r.count {
            r[i] ^= b[i];
        }
        return r;
    }
    
    func groupPartOfString(m: NSTextCheckingResult, group: Int, str: NSString) -> String? {
        guard group < m.numberOfRanges else {
            log("trying to retrive group", group, "not existing in", m);
            return nil;
        }
        
        let r = m.rangeAtIndex(group);
        guard r.length != 0 else {
            return "";
        }
        
        return str.substringWithRange(r);
    }
    
    class Data {
        var authMessage: String?;
        var cb: String = "n,";
        var clientFirstMessageBare: String?;
        var conce: String?;
        var saltedPassword = [UInt8]();
        var stage: Int = 0;
    }
}
