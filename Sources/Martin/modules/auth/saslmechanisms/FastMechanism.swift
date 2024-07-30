//
// FastMechanism.swift
//
// TigaseSwift
// Copyright (C) 2022 "Tigase, Inc." <office@tigase.com>
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

extension Sasl2InlineStageFeatures.Feature {
    
    public static let fast0 = Sasl2InlineStageFeatures.Feature(name: "fast", xmlns: "urn:xmpp:fast:0");
    
}

extension Sasl2InlineStageFeatures {
    
    public var fast: FAST? {
        guard let fastEl = self.get(.fast0) else {
            return nil;
        }
        
        return FAST(element: fastEl);
    }
    
    public struct FAST {
     
        public let element: Element;
        
        public var mechanisms: [String] {
            return element.filterChildren(name: "mechanism").compactMap({ $0.value });
        }
        
        init(element: Element) {
            self.element = element;
        }
        
    }

}

public protocol FastMechanismProtocol {}

open class FastMechanism<Hash: HashAlgorithm>: FastMechanismProtocol, Sasl2MechanismFeaturesAware {
    
    private var requstedToken: Bool = false;
    
    private func bestMechanism(context: Context, mechanisms: [String]) -> String? {
        let fastMechanisms = Set(mechanisms);
        return context.module(.sasl2).mechanisms.map({ $0.name }).filter({ fastMechanisms.contains($0) }).first;
    }
    
    open func feature(context: Context, sasl2: StreamFeatures.SASL2) -> Element? {
        guard let fast = sasl2.inline.fast else {
            return nil;
        }
        if self.status == .inProgress {
            return Element(name: "fast", xmlns: "urn:xmpp:fast:0");
        }
        
        if let bestMech = bestMechanism(context: context, mechanisms: fast.mechanisms), bestMech == name {
            self.requstedToken = true;
            return Element(name: "request-token", xmlns: "urn:xmpp:fast:0") {
                Attribute("mechanism", value: bestMech);
            }
        }
        return nil;
    }
    
    open func process(result: Element, context: Context) {
        if requstedToken, let tokenEl = result.firstChild(name: "token", xmlns: "urn:xmpp:fast:0"), let expiry = TimestampHelper.parse(timestamp: tokenEl.attribute("expiry")), let value = tokenEl.attribute("token") {
            let token = FastMechanismToken(mechanism: self.name, value: value, expiresAt: expiry);
            context.connectionConfiguration.credentials.fastToken = token;
        }
    }
    
    private let INITIATOR = "Initiator".data(using: .utf8)!;
    private let RESPONDER = "Responder".data(using: .utf8)!;

    public let name: String
    private let channelBinding: ChannelBinding?;
    
    public private(set) var status: SaslMechanismStatus = .new;
    
    public static func mechanisms(for bindings: [ChannelBinding?] = [.tlsExporter,.tlsUnique,.tlsServerEndPoint,.none]) -> [SaslMechanism] {
        return bindings.map({ FastMechanism.init(channelBinding: $0) });
    }
    
    private static func suffix(for binding: ChannelBinding?) -> String {
        switch binding {
        case .tlsServerEndPoint:
            return "ENDP";
        case .tlsExporter:
            return "EXPR";
        case .none:
            return "NONE";
        case .tlsUnique:
            return "UNIQ";
        }
    }
    
    public init(channelBinding: ChannelBinding?) {
        self.name = "HT-\(Hash.name)-\(FastMechanism.suffix(for: channelBinding))";
        self.channelBinding = channelBinding;
    }
    
    public func reset(scopes: Set<ResetableScope>) {
        if scopes.contains(.stream) {
            status = .new;
        }
    }
    
    public func evaluateChallenge(_ input: String?, context: Context) throws -> String? {
        if let input = input {
            guard let response = Data(base64Encoded: input) else {
                throw ClientSaslException.badChallenge(msg: "Response not properly encoded");
            }
            guard let token = context.connectionConfiguration.credentials.fastToken, token.mechanism == name, let tokenData = token.value.data(using: .utf8) else {
                throw SaslError(cause: .invalid_mechanism, message: "Missing FAST token (input)");
            }

            let cbData = (channelBinding != nil ? try (context as? XMPPClient)?.connector?.channelBindingData(type: channelBinding!) : nil) ?? Data();
            let expectedResponse = Hash.hmac(key: tokenData, data: RESPONDER + cbData);
            guard response == expectedResponse else {
                throw ClientSaslException.invalidServerSignature;
            }
            
            self.status = .completed;
            return nil;
        } else {
            guard let token = context.connectionConfiguration.credentials.fastToken, token.mechanism == name, let tokenData = token.value.data(using: .utf8)  else {
                throw SaslError(cause: .invalid_mechanism, message: "Missing FAST token (no input)");
            }

            let cbData = (channelBinding != nil ? try (context as? XMPPClient)?.connector?.channelBindingData(type: channelBinding!) : nil) ?? Data();
            let hashedToken = Hash.hmac(key: tokenData, data: INITIATOR + cbData);
            let firstMessage = (context.userBareJid.localPart!).data(using: .utf8)! + Data(repeating: 0, count: 1) + hashedToken;
            self.status = .inProgress;
            return firstMessage.base64EncodedString();
        }
    }
        
    open func isAllowedToUse(_ context: Context, features: StreamFeatures) -> Bool {
        guard let sasl2Features = features.sasl2?.inline, let fast = sasl2Features.fast, fast.mechanisms.contains(self.name) else {
            return false;
        }
        guard let token = context.connectionConfiguration.credentials.fastToken else {
            return false;
        }
        return token.mechanism == self.name && token.expiresAt.timeIntervalSince(Date()) > 10.0;
    }
    
}

public struct FastMechanismToken {
    public let mechanism: String;
    public let value: String;
    public let expiresAt: Date;
    
    public init(mechanism: String, value: String, expiresAt: Date) {
        self.mechanism = mechanism;
        self.value = value;
        self.expiresAt = expiresAt;
    }
}

