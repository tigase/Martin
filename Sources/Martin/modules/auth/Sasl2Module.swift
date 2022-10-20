//
// Sasl2Module.swift
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
import TigaseLogging
import Combine

extension XmppModuleIdentifier {
    public static var sasl2: XmppModuleIdentifier<Sasl2Module> {
        return Sasl2Module.IDENTIFIER;
    }
}

extension StreamFeatures.StreamFeature {
    
    public static let sasl2 = StreamFeatures.StreamFeature(name: "authentication", xmlns: "urn:xmpp:sasl:2");
    
    public static let saslChannelBinding = StreamFeatures.StreamFeature(name: "sasl-channel-binding", xmlns: "urn:xmpp:sasl-cb:0");
    
}

/**
 Module provides support for [XEP-0388: Extensible SASL Profile] and [XEP-0386: Bind 2.0]
 
 [XEP-0386: Bind 2.0]:https://xmpp.org/extensions/xep-0386.html
 [XEP-0388: Extensible SASL Profile]: https://xmpp.org/extensions/xep-0388.html
 */
open class Sasl2Module: XmppModuleBase, XmppModule, Resetable, @unchecked Sendable {
    /// Namespace used SASL negotiation and authentication
    static let SASL2_XMLNS = "urn:xmpp:sasl:2";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = SASL2_XMLNS;
    public static let IDENTIFIER = XmppModuleIdentifier<Sasl2Module>();
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "Sasl2Module")

    private var cancellable: Cancellable?;
    open override var context: Context? {
        didSet {
            self.store(context?.module(.streamFeatures).$streamFeatures.map({ Sasl2Module.supportedMechanisms(streamFeatures: $0) }).assign(to: \.supportedMechanisms, on: self));
        }
    }

    public let features = [String]();
    
    private var lock = UnfairLock();
    private var mechanisms = [String:SaslMechanism]();
    private var _mechanismsOrder = [String]();
    
    private var supportedMechanisms: [String] = [];
        
    open var software: String?;
    open var deviceName: String?;
    open var deviceId: String?;

    open var shouldBind: Bool = true;
    open var shouldUpgrade: Bool = true;
    
    open var isSupported: Bool {
        return context?.module(.streamFeatures).streamFeatures.contains(.sasl2) ?? false;
    }
    
    /// Order of mechanisms preference
    open var mechanismsOrder:[String] {
        get {
            return lock.with({
                return _mechanismsOrder;
            })
        }
        set {
            lock.with({
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
            })
        }
    }
    
    public override init() {
        super.init();
        self.addMechanism(ScramMechanism.ScramSha256Plus());
        self.addMechanism(ScramMechanism.ScramSha256());
        self.addMechanism(ScramMechanism.ScramSha1Plus());
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
        lock.with({
            self.mechanisms[mechanism.name] = mechanism;
            if (first) {
                self._mechanismsOrder.insert(mechanism.name, at: 0);
            } else {
                self._mechanismsOrder.append(mechanism.name);
            }
        })
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
            case "continue":
                try await processContinue(elem, mechanism: mechanism);
            case "data", "parameters":
                try await saslUpgrade(elem, mechanism: mechanism);
            default:
                throw XMPPError(condition: .feature_not_implemented, stanza: elem);
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
        
        let sasl2Features = Sasl2InlineStageFeatures(streamFeatures: context?.module(.streamFeatures).streamFeatures);
        
        let upgrades = context?.module(.streamFeatures).streamFeatures.get(.sasl2)?.filterChildren(name: "upgrade").compactMap({ $0.value }).filter({ mechanisms[$0]?.supportsUpgrade ?? false });
        
        let result = try mechanism.evaluateChallenge(nil, context: context!);
        let auth = Stanza(name: "authenticate", xmlns: Sasl2Module.SASL2_XMLNS, {
            Attribute("mechanism", value: mechanism.name);
            Attribute("upgrade", value: upgrades?.first)
            Element(name: "initial-response", cdata: result)
            Element(name: "user-agent", {
                Attribute("id", value: self.deviceId)
                Element(name: "software", cdata: self.software ?? context?.moduleOrNil(.softwareVersion)?.version.name)
                Element(name: "device", cdata: self.deviceName ?? context?.connectionConfiguration.resource)
            })
            for inline in (context?.modules(Sasl2InlineProtocol.self) ?? []) {
                if let feature = inline.featureFor(stage: .afterSasl(sasl2Features)) {
                    feature;
                }
            }
            if shouldBind {
                Element(name: "bind", xmlns: "urn:xmpp:bind:0", {
                    Element(name: "tag", cdata: "Martin")
                    if let inlines = context?.modules(Sasl2InlineProtocol.self), !inlines.isEmpty {
                        inlines.compactMap({ $0.featureFor(stage: .afterBind(Bind2InlineStageFeatures(sasl2Features: sasl2Features))) })
                    }
                })
            }
        });
                
        let response = try await write(stanza: auth, for: .init(names: ["success", "failure", "challenge", "continue"], xmlns: Sasl2Module.SASL2_XMLNS));
        try await handleResponse(stanza: response, mechanism: mechanism);
    }
    
    private func processContinue(_ stanza: Stanza, mechanism: SaslMechanism) async throws {
        if mechanism.status != .completed, let data = stanza.firstChild(name: "additional-data")?.value {
            _ = try mechanism.evaluateChallenge(data, context: context!);
        }
        
        if mechanism.status == .completed {
            logger.debug("Authenticated - continue");
        } else {
            logger.debug("Authenticated by server but responses not accepted by client. - continue");
            throw SaslError.server_not_trusted;
        }
        
        let tasks = stanza.firstChild(name: "tasks")?.filterChildren(name: "task").compactMap({ $0.value }) ?? [];
        
        if let upgrade = tasks.first(where: { $0.starts(with: "UPGR-") })?.dropFirst(5) {
            guard let mechanism = mechanisms[String(upgrade)] else {
                throw XMPPError(condition: .feature_not_implemented, message: "Requested upgrade to unsupported mechanism: \(upgrade)");
            }
            let response = try await write(stanza: Stanza(name: "next", xmlns: Sasl2Module.SASL2_XMLNS, {
                Attribute("task", value: "UPGR-\(upgrade)")
            }), for: .init(names: ["data", "parameters", "failure", "success"], xmlns: Sasl2Module.SASL2_XMLNS));
            try await handleResponse(stanza: response, mechanism: mechanism)
        } else {
            throw XMPPError(condition: .feature_not_implemented, message: "Required unsupported SASL2 task", stanza: stanza);
        }
    }
    
    private func saslUpgrade(_ stanza: Stanza, mechanism: SaslMechanism) async throws {
        let hash = try await mechanism.evaluateUpgrade(parameters: stanza.element, context: context!);
        let response = try await write(stanza: Stanza(element: hash), for: .init(names: ["failure","success"], xmlns: Sasl2Module.SASL2_XMLNS));
        try await handleResponse(stanza: response, mechanism: mechanism);
    }
    
    private func processSuccess(_ stanza: Stanza, mechanism: SaslMechanism) throws {
        if mechanism.status != .completed, let data = stanza.firstChild(name: "additional-data")?.value {
            _ = try mechanism.evaluateChallenge(data, context: context!);
        }
        for inline in self.context?.modules(Sasl2InlineProtocol.self) ?? [] {
            inline.process(result: stanza.element, for: .afterSasl);
        }
        if let bound = stanza.element.firstChild(name: "bound", xmlns: "urn:xmpp:bind:0") {
            self.context?.boundJid = JID(stanza.firstChild(name: "authorization-identifier")?.value);
            for inline in self.context?.modules(Sasl2InlineProtocol.self) ?? [] {
                inline.process(result: bound, for: .afterBind)
            }
        }
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
        let request = Stanza(name: "response", xmlns: Sasl2Module.SASL2_XMLNS, value: result);
        
        let response = try await write(stanza: request, for: .init(names: ["success", "failure", "challenge", "continue"], xmlns: Sasl2Module.SASL2_XMLNS));
        try await handleResponse(stanza: response, mechanism: mechanism);
    }
    
    static func supportedMechanisms(streamFeatures: StreamFeatures) -> [String] {
        return streamFeatures.get(.sasl2)?.filterChildren(name: "mechanism").compactMap({ $0.value }) ?? [];
    }
    
    func guessSaslMechanism() -> SaslMechanism? {
        let supported = self.supportedMechanisms;
        for name in mechanismsOrder {
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

public enum Sasl2InlineOfferStage {
    case afterSasl(Sasl2InlineStageFeatures)
    case afterBind(Bind2InlineStageFeatures)
}

public enum Sasl2InlineResultStage {
    case afterSasl
    case afterBind
}

public protocol Sasl2InlineProtocol {

    func featureFor(stage: Sasl2InlineOfferStage) -> Element?
    func process(result: Element, for stage: Sasl2InlineResultStage)
    
}

public struct Sasl2InlineStageFeatures: Sendable {
 
    public let element: Element;
    
    init(streamFeatures: StreamFeatures?) {
        self.init(element: streamFeatures?.get(.sasl2)?.firstChild(name: "inline"));
    }
    
    init(element: Element?) {
        self.element = element ?? Element(name: "inline");
    }
    
    public func contains(_ feature: Sasl2InlineStageFeatures.Feature) -> Bool {
        return feature.test(in: element);
    }
    
    public func get(_ feature: Sasl2InlineStageFeatures.Feature) -> Element? {
        return feature.get(from: element);
    }
    
    public struct Feature {
        public let name: String;
        public let xmlns: String;
        
        public init(name: String, xmlns: String) {
            self.name = name
            self.xmlns = xmlns
        }
     
        public func get(from element: Element) -> Element? {
            return element.firstChild(name: name, xmlns: xmlns);
        }
        
        public func test(in element: Element) -> Bool {
            return element.hasChild(name: name, xmlns: xmlns);
        }
    }
}

public struct Bind2InlineStageFeatures: Sendable {
 
    public let element: Element;
    
    init(sasl2Features: Sasl2InlineStageFeatures) {
        self.init(element: sasl2Features.get(.bind2)?.firstChild(name: "inline"));
    }
    
    init(element: Element?) {
        self.element = element ?? Element(name: "inline");
    }
    
    public func contains(_ feature: Bind2InlineStageFeatures.Feature) -> Bool {
        return feature.test(in: element);
    }
    
    public struct Feature {
        public let `var`: String;
        
        public init(`var`: String) {
            self.var = `var`;
        }

        public func get(from element: Element) -> Element? {
            return element.firstChild(where: { "feature" == $0.name && `var` == $0.attribute("var") });
        }
        
        public func test(in element: Element) -> Bool {
            return get(from: element) != nil;
        }
    }
}

extension Sasl2InlineStageFeatures.Feature {
    public static let bind2 = Sasl2InlineStageFeatures.Feature(name: "bind", xmlns: "urn:xmpp:bind:0");
}
