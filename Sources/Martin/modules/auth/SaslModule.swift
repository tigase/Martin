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
open class SaslModule: XmppModuleBase, XmppModule, Resetable, @unchecked Sendable {
    /// Namespace used SASL negotiation and authentication
    static let SASL_XMLNS = "urn:ietf:params:xml:ns:xmpp-sasl";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = SASL_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<SaslModule>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "SaslModule")

    private var cancellable: Cancellable?;
    open override var context: Context? {
        didSet {
            self.store(context?.module(.streamFeatures).$streamFeatures.map({ SaslModule.supportedMechanisms(streamFeatures: $0) }).assign(to: \.supportedMechanisms, on: self));
        }
    }

    public let features = [String]();
    
    private var supportedMechanisms: [String] = [];
    
    open var mechanisms: [SaslMechanism] {
        return context?.connectionConfiguration.saslMechanisms.filter({ !($0 is Sasl2MechanismFeaturesAware) }) ?? [];
    }
    
    public override init() {
        super.init();
    }
    
    open func reset(scopes: Set<ResetableScope>) {
        for mechanism in mechanisms {
            mechanism.reset(scopes: scopes);
        }
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
            throw SaslError(cause: .temporary_auth_failure, message: msg);
        } catch ClientSaslException.genericError(let msg) {
            logger.debug("Generic error happened: \(msg ?? "nil")");
            throw SaslError(cause: .temporary_auth_failure, message: msg);
        } catch ClientSaslException.invalidServerSignature {
            logger.debug("Received answer from server with invalid server signature!");
            throw SaslError(cause: .server_not_trusted, message: "Invalid server signature");
        } catch ClientSaslException.wrongNonce {
            logger.debug("Received answer from server with wrong nonce!");
            throw SaslError(cause: .server_not_trusted, message: "Wrong nonce");
        }
    }
    
    /**
     Begin SASL authentication process
     */
    open func login() async throws {
        guard let mechanism = guessSaslMechanism(features: context!.module(.streamFeatures).streamFeatures) else {
            throw SaslError(cause: .invalid_mechanism, message: "No usable mechamism");
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
            throw SaslError(cause: .server_not_trusted, message: "Client rejected server response");
        }
    }
    
    private func processFailure(_ stanza: Stanza, mechanism: SaslMechanism) throws {
        let msg = stanza.children.first(where: { el in el.name == "text"})?.value;
        guard let errorName = stanza.children.first(where: { el in el.name != "text"})?.name, let errorCause = SaslError.Cause(rawValue: errorName) else {
            throw SaslError(cause: .not_authorized, message: msg);
        }
        logger.error("Authentication failed with error: \(errorCause), \(errorName), \(msg ?? "nil")");
        throw SaslError(cause: errorCause, message: msg);
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
    
    func guessSaslMechanism(features: StreamFeatures) -> SaslMechanism? {
        let supported = self.supportedMechanisms;
        for mechanism in mechanisms{
            if (!supported.contains(mechanism.name)) {
                continue;
                }
            if (mechanism.isAllowedToUse(context!, features: features)) {
                return mechanism;
            }
        }
        return nil;
    }

}
