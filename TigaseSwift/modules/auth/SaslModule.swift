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

/**
 Module provides support for [SASL negotiation and authentication]
 
 [SASL negotiation and authentication]: https://tools.ietf.org/html/rfc6120#section-6
 */
open class SaslModule: Logger, XmppModule, ContextAware {
    /// Namespace used SASL negotiation and authentication
    static let SASL_XMLNS = "urn:ietf:params:xml:ns:xmpp-sasl";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = SASL_XMLNS;
    
    fileprivate static let SASL_MECHANISM = "saslMechanism";
    
    public let id = SASL_XMLNS;

    public let criteria = Criteria.or(
        Criteria.name("success", xmlns: SASL_XMLNS),
        Criteria.name("failure", xmlns: SASL_XMLNS),
        Criteria.name("challenge", xmlns: SASL_XMLNS)
    );
    
    public let features = [String]();
    
    open var context:Context!;
    
    fileprivate var mechanisms = [String:SaslMechanism]();
    fileprivate var _mechanismsOrder = [String]();
    
    open var inProgress: Bool {
        guard let mechanism: SaslMechanism = context.sessionObject.getProperty(SaslModule.SASL_MECHANISM) else {
            return false;
        }
        
        return mechanism.isCompleteExpected(context.sessionObject) && !mechanism.isComplete(context.sessionObject);
    }
    
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
            log("Received bad challenge from server: \(String(describing: msg))");
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.temporary_auth_failure));
        } catch ClientSaslException.genericError(let msg) {
            log("Generic error happened: \(String(describing: msg))");
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.temporary_auth_failure));
        } catch ClientSaslException.invalidServerSignature {
            log("Received answer from server with invalid server signature!");
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.server_not_trusted));
        } catch ClientSaslException.wrongNonce {
            log("Received answer from server with wrong nonce!");
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.server_not_trusted));
        }
    }
    
    /**
     Begin SASL authentication process
     */
    open func login() {
        guard let mechanism = guessSaslMechanism() else {
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.invalid_mechanism));
            return;
        }
        context.sessionObject.setProperty(SaslModule.SASL_MECHANISM, value: mechanism, scope: SessionObject.Scope.stream);
        
        do {
            let auth = Stanza(name: "auth");
            auth.element.xmlns = SaslModule.SASL_XMLNS;
            auth.element.setAttribute("mechanism", value: mechanism.name);
            auth.element.value = try mechanism.evaluateChallenge(nil, sessionObject: context.sessionObject);
        
            context.eventBus.fire(SaslAuthStartEvent(sessionObject:context.sessionObject, mechanism: mechanism.name))
        
            context.writer!.write(auth);
            
            if mechanism.isCompleteExpected(context.sessionObject) {
                context.writer?.execAfterWrite {
                    self.context.eventBus.fire(AuthModule.AuthFinishExpectedEvent(sessionObject: self.context.sessionObject));
                }
            }
        } catch _ {
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.aborted));
        }
    }
    
    func processSuccess(_ stanza: Stanza) throws {
        let mechanism: SaslMechanism? = context.sessionObject.getProperty(SaslModule.SASL_MECHANISM);
        _ = try mechanism!.evaluateChallenge(stanza.element.value, sessionObject: context.sessionObject);
        
        if mechanism!.isComplete(context.sessionObject) {
            log("Authenticated");
            context.eventBus.fire(SaslAuthSuccessEvent(sessionObject: context.sessionObject));
        } else {
            log("Authenticated by server but responses not accepted by client.");
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.server_not_trusted));
        }
    }
    
    func processFailure(_ stanza: Stanza) throws {
        context.sessionObject.setProperty(SaslModule.SASL_MECHANISM, value: nil);
        let errorName = stanza.findChild()?.name;
        let error = errorName == nil ? nil : SaslError(rawValue: errorName!);
        log("Authentication failed with error:", error, errorName);
        
        context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: error ?? SaslError.not_authorized));
    }
    
    func processChallenge(_ stanza: Stanza) throws {
        guard let mechanism: SaslMechanism = context.sessionObject.getProperty(SaslModule.SASL_MECHANISM) else {
            return;
        }
        if mechanism.isComplete(context.sessionObject) {
            throw ErrorCondition.bad_request;
        }
        let challenge = stanza.element.value;
        let response = try mechanism.evaluateChallenge(challenge, sessionObject: context.sessionObject);
        let responseEl = Stanza(name: "response");
        responseEl.element.xmlns = SaslModule.SASL_XMLNS;
        responseEl.element.value = response;
        context.writer?.write(responseEl);
        
        if mechanism.isCompleteExpected(context.sessionObject) {
            context.writer?.execAfterWrite {
                self.context.eventBus.fire(AuthModule.AuthFinishExpectedEvent(sessionObject: self.context.sessionObject));
            }
        }
    }
    
    func getSupportedMechanisms() -> [String] {
        var result = [String]();
        StreamFeaturesModule.getStreamFeatures(context.sessionObject)?.findChild(name: "mechanisms")?.forEachChild(name: "mechanism", fn: { (mech:Element) -> Void in
            result.append(mech.value!);
        });
        return result;
    }
    
    func guessSaslMechanism() -> SaslMechanism? {
        let supported = getSupportedMechanisms();
        for name in _mechanismsOrder {
            if let mechanism = mechanisms[name] {
                if (!supported.contains(name)) {
                    continue;
                }
                if (mechanism.isAllowedToUse(context.sessionObject)) {
                    return mechanism;
                }
            }
        }
        return nil;
    }
    
    /// Event fired when SASL authentication fails
    open class SaslAuthFailedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SaslAuthFailedEvent();
        
        public let type = "SaslAuthFailedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Error which occurred
        public let error:SaslError!;
        
        init() {
            sessionObject = nil;
            error = nil;
        }
        
        public init(sessionObject: SessionObject, error: SaslError) {
            self.sessionObject = sessionObject;
            self.error = error;
        }
    }
    
    /// Event fired when SASL authentication begins
    open class SaslAuthStartEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SaslAuthStartEvent();
        
        public let type = "SaslAuthStartEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Mechanism used during authentication
        public let mechanism:String!;
        
        init() {
            sessionObject = nil;
            mechanism = nil;
        }
        
        public init(sessionObject: SessionObject, mechanism:String) {
            self.sessionObject = sessionObject;
            self.mechanism = mechanism;
        }
    }
    
    /// Event fired after successful authentication
    open class SaslAuthSuccessEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = SaslAuthSuccessEvent();
        
        public let type = "SaslAuthSuccessEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
    }
}
