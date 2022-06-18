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

    public let criteria = Criteria.or(
        Criteria.name("success", xmlns: SASL_XMLNS),
        Criteria.name("failure", xmlns: SASL_XMLNS),
        Criteria.name("challenge", xmlns: SASL_XMLNS)
    );
    
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
    
    // remember to clear it! ie. on SessionObject being cleared!
    private var mechanismInUse: SaslMechanism?;
    
    open var inProgress: Bool {
        return (mechanismInUse?.status ?? .new) == .completedExpected;
    }
    
    @Published
    public private(set) var state: AuthModule.AuthorizationStatus = .notAuthorized;
    
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
        self.mechanismInUse = nil;
        if state != .notAuthorized {
            self.state = .notAuthorized;
        }
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
        do {
        switch elem.name {
            case "success":
                try processSuccess(elem);
            case "failure":
                try processFailure(elem);
            case "challenge":
                try processChallenge(elem);
            default:
                break;
            }
        } catch ClientSaslException.badChallenge(let msg) {
            logger.debug("Received bad challenge from server: \(msg ?? "nil")");
            self.state = .error(SaslError.temporary_auth_failure);
        } catch ClientSaslException.genericError(let msg) {
            logger.debug("Generic error happened: \(msg ?? "nil")");
            self.state = .error(SaslError.temporary_auth_failure);
        } catch ClientSaslException.invalidServerSignature {
            logger.debug("Received answer from server with invalid server signature!");
            self.state = .error(SaslError.server_not_trusted);
        } catch ClientSaslException.wrongNonce {
            logger.debug("Received answer from server with wrong nonce!");
            self.state = .error(SaslError.server_not_trusted);
        }
    }
    
    /**
     Begin SASL authentication process
     */
    open func login() {
        if state != .notAuthorized {
            self.state = .notAuthorized;
        }
        guard let mechanism = guessSaslMechanism() else {
            self.state = .error(SaslError.invalid_mechanism);
            return;
        }
        self.mechanismInUse = mechanism;
        
        do {
            let auth = Stanza(name: "auth");
            auth.element.xmlns = SaslModule.SASL_XMLNS;
            auth.element.setAttribute("mechanism", value: mechanism.name);
            auth.element.value = try mechanism.evaluateChallenge(nil, context: context!);
        
            if state != .inProgress {
                self.state = .inProgress;
            }
            
            write(auth, writeCompleted: { _ in
                if mechanism.status == .completedExpected {
                    self.state = .expectedAuthorization;
                }
            });
            
        } catch let error {
            logger.error("Authentication aborted: \(error)")
            self.state = .error(SaslError.aborted);
        }
    }
    
    func processSuccess(_ stanza: Stanza) throws {
        let mechanism: SaslMechanism? = self.mechanismInUse;
        _ = try mechanism!.evaluateChallenge(stanza.element.value, context: context!);
        
        if mechanism!.status == .completed {
            logger.debug("Authenticated");
            if state != .authorized {
                self.state = .authorized;
            }
        } else {
            logger.debug("Authenticated by server but responses not accepted by client.");
            self.state = .error(SaslError.server_not_trusted);
        }
    }
    
    func processFailure(_ stanza: Stanza) throws {
        self.mechanismInUse = nil;
        let errorName = stanza.findChild()?.name;
        let error = errorName == nil ? nil : SaslError(rawValue: errorName!);
        logger.error("Authentication failed with error: \(error), \(errorName)");
        self.state = .error(error ?? SaslError.not_authorized);
    }
    
    func processChallenge(_ stanza: Stanza) throws {
        guard let mechanism: SaslMechanism = self.mechanismInUse else {
            return;
        }
        if mechanism.status == .completed {
            throw XMPPError.bad_request("Authentication is already completed!");
        }
        let challenge = stanza.element.value;
        let response = try mechanism.evaluateChallenge(challenge, context: context!);
        let responseEl = Stanza(name: "response");
        responseEl.element.xmlns = SaslModule.SASL_XMLNS;
        responseEl.element.value = response;
        write(responseEl, writeCompleted: { result in
            if mechanism.status == .completedExpected {
                self.state = .expectedAuthorization;
            }
        });
        
    }
    
    static func supportedMechanisms(streamFeatures: StreamFeatures) -> [String] {
        return streamFeatures.element?.findChild(name: "mechanisms")?.mapChildren(transform: { $0.value }, filter: { $0.name == "mechanism" }) ?? [];
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
