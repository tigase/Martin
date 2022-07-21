//
// SaslModule.swift
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
import TigaseLogging
import Combine

extension XmppModuleIdentifier {
    public static var sasl: XmppModuleIdentifier<SaslModule> {
        return SaslModule.IDENTIFIER;
    }
}

/**
 Module provides support for [SASL negotiation and authentication]
 
 [SASL negotiation and authentication]: https://tools.ietf.org/html/rfc6120#section-6
 */
open class SaslModule: XmppModuleBase, XmppModule, Resetable {
    /// Namespace used SASL negotiation and authentication
    static let SASL_XMLNS = "urn:ietf:params:xml:ns:xmpp-sasl";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = SASL_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<SaslModule>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "SaslModule")

    public let criteria: Criteria = .false;
    
    private var cancellable: Cancellable?;
    open override var context: Context? {
        didSet {
            self.store(context?.module(.streamFeatures).$streamFeatures.map({ SaslModule.supportedMechanisms(streamFeatures: $0) }).assign(to: \.supportedMechanisms, on: self));
        }
    }

    public let features = [String]();
    
    private var mechanisms = [String:SaslMechanism]();
    private var _mechanismsOrder = [String]();
    
    private var supportedMechanisms: [String] = [];
        
    /// Order of mechanisms preference
    open var mechanismsOrder:[String] {
        get {
            return _mechanismsOrder;
        }
        set {
            var value = newValue;
            for name in newValue {
                if mechanisms[name] == nil {
                    value.remove(at: value.firstIndex(of: name)!);
                }
            }
            for name in mechanisms.keys {
                if value.firstIndex(of: name) == nil {
                    mechanisms.removeValue(forKey: name);
                }
            }
        }
    }
    
    public override init() {
        super.init();
        self.addMechanism(ScramMechanism.ScramSha256());
        self.addMechanism(ScramMechanism.ScramSha1());
        self.addMechanism(PlainMechanism());
        self.addMechanism(AnonymousMechanism());
    }
    
    open func reset(scopes: Set<ResetableScope>) {
        for mechanism in mechanisms.values {
            mechanism.reset(scopes: scopes);
        }
    }
    
    /**
     Add implementation of `SaslMechanism`
     - parameter mechanism: implementation of mechanism
     - parameter first: add as best mechanism to use
     */
    open func addMechanism(_ mechanism:SaslMechanism, first:Bool = false) {
        self.mechanisms[mechanism.name] = mechanism;
        if (first) {
            self._mechanismsOrder.insert(mechanism.name, at: 0);
        } else {
            self._mechanismsOrder.append(mechanism.name);
        }
    }
    
    open func process(stanza elem: Stanza) throws {
        throw XMPPError(condition: .bad_request);
    }
    
    private func handleResponse(stanza elem: Stanza, mechanism: SaslMechanism) async throws {
        do {
        switch elem.name {
            case "success":
                try processSuccess(elem, mechanism: mechanism);
            case "failure":
                try processFailure(elem, mechanism: mechanism);
            case "challenge":
                try await processChallenge(elem, mechanism: mechanism);
            default:
                break;
            }
        } catch ClientSaslException.badChallenge(let msg) {
            logger.debug("Received bad challenge from server: \(msg ?? "nil")");
            throw SaslError.temporary_auth_failure;
        } catch ClientSaslException.genericError(let msg) {
            logger.debug("Generic error happened: \(msg ?? "nil")");
            throw SaslError.temporary_auth_failure;
        } catch ClientSaslException.invalidServerSignature {
            logger.debug("Received answer from server with invalid server signature!");
            throw SaslError.server_not_trusted;
        } catch ClientSaslException.wrongNonce {
            logger.debug("Received answer from server with wrong nonce!");
            throw SaslError.server_not_trusted;
        }
    }
    
    /**
     Begin SASL authentication process
     */
    open func login() async throws {
        guard let mechanism = guessSaslMechanism() else {
            throw SaslError.invalid_mechanism;
        }
        
        let result = try mechanism.evaluateChallenge(nil, context: context!);
        let auth = Stanza(name: "auth", xmlns: SaslModule.SASL_XMLNS, value: result, {
            Attribute("mechanism", value: mechanism.name);
        });
                
        let response = try await write(stanza: auth, for: .init(names: ["success", "failure", "challenge"], xmlns: SaslModule.SASL_XMLNS));
        try await handleResponse(stanza: response, mechanism: mechanism);
    }
    
    private func processSuccess(_ stanza: Stanza, mechanism: SaslMechanism) throws {
        _ = try mechanism.evaluateChallenge(stanza.element.value, context: context!);
        
        if mechanism.status == .completed {
            logger.debug("Authenticated");
        } else {
            logger.debug("Authenticated by server but responses not accepted by client.");
            throw SaslError.server_not_trusted;
        }
    }
    
    private func processFailure(_ stanza: Stanza, mechanism: SaslMechanism) throws {
        guard let errorName = stanza.children.first?.name, let error = SaslError(rawValue: errorName) else {
            throw SaslError.not_authorized;
        }
        logger.error("Authentication failed with error: \(error), \(errorName)");
        throw error;
    }
    
    private func processChallenge(_ stanza: Stanza, mechanism: SaslMechanism) async throws {
        if mechanism.status == .completed {
            throw XMPPError(condition: .bad_request, message: "Authentication is already completed!");
        }
        let challenge = stanza.value;
        let result = try mechanism.evaluateChallenge(challenge, context: context!);
        let request = Stanza(name: "response", xmlns: SaslModule.SASL_XMLNS, value: result);
        
        let response = try await write(stanza: request, for: .init(names: ["success", "failure", "challenge"], xmlns: SaslModule.SASL_XMLNS));
        try await handleResponse(stanza: response, mechanism: mechanism);
    }
    
    static func supportedMechanisms(streamFeatures: StreamFeatures) -> [String] {
        return streamFeatures.element?.firstChild(name: "mechanisms")?.filterChildren(name: "mechanism").compactMap({ $0.value }) ?? [];
    }
    
    func guessSaslMechanism() -> SaslMechanism? {
        let supported = self.supportedMechanisms;
        for name in _mechanismsOrder {
            if let mechanism = mechanisms[name] {
                if (!supported.contains(name)) {
                    continue;
                }
                if (mechanism.isAllowedToUse(context!)) {
                    return mechanism;
                }
            }
        }
        return nil;
    }

}
