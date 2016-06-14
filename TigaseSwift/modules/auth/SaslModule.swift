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
public class SaslModule: Logger, XmppModule, ContextAware {
    /// Namespace used SASL negotiation and authentication
    static let SASL_XMLNS = "urn:ietf:params:xml:ns:xmpp-sasl";
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = SASL_XMLNS;
    
    private static let SASL_MECHANISM = "saslMechanism";
    
    public let id = SASL_XMLNS;

    public let criteria = Criteria.or(
        Criteria.name("success", xmlns: SASL_XMLNS),
        Criteria.name("failure", xmlns: SASL_XMLNS),
        Criteria.name("challenge", xmlns: SASL_XMLNS)
    );
    
    public let features = [String]();
    
    public var context:Context!;
    
    private var mechanisms = [String:SaslMechanism]();
    private var _mechanismsOrder = [String]();
    
    /// Order of mechanisms preference
    public var mechanismsOrder:[String] {
        get {
            return _mechanismsOrder;
        }
        set {
            var value = newValue;
            for name in newValue {
                if mechanisms[name] == nil {
                    value.removeAtIndex(value.indexOf(name)!);
                }
            }
            for name in mechanisms.keys {
                if value.indexOf(name) == nil {
                    mechanisms.removeValueForKey(name);
                }
            }
        }
    }
    
    public override init() {
        super.init();
        self.addMechanism(PlainMechanism());
    }
    
    /**
     Add implementation of `SaslMechanism`
     - parameter mechanism: implementation of mechanism
     - parameter first: add as best mechanism to use
     */
    public func addMechanism(mechanism:SaslMechanism, first:Bool = false) {
        self.mechanisms[mechanism.name] = mechanism;
        if (first) {
            self._mechanismsOrder.insert(mechanism.name, atIndex: 0);
        } else {
            self._mechanismsOrder.append(mechanism.name);
        }
    }
    
    public func process(elem: Stanza) throws {
        switch elem.name {
        case "success":
            processSuccess(elem);
        case "failure":
            processFailure(elem);
        case "challenge":
            try processChallenge(elem);
        default:
            break;
        }
    }
    
    /**
     Begin SASL authentication process
     */
    public func login() {
        let mechanism = guessSaslMechanism();
        if mechanism == nil {
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.invalid_mechanism));
            return;
        }
        context.sessionObject.setProperty(SaslModule.SASL_MECHANISM, value: mechanism, scope: SessionObject.Scope.stream);
        
        let auth = Stanza(name: "auth");
        auth.element.xmlns = SaslModule.SASL_XMLNS;
        auth.element.setAttribute("mechanism", value: mechanism!.name);
        auth.element.value = mechanism?.evaluateChallenge(nil, sessionObject: context.sessionObject);
        
        context.eventBus.fire(SaslAuthStartEvent(sessionObject:context.sessionObject, mechanism: mechanism!.name))
        
        context.writer!.write(auth);
    }
    
    func processSuccess(stanza: Stanza) {
        let mechanism: SaslMechanism? = context.sessionObject.getProperty(SaslModule.SASL_MECHANISM);
        mechanism!.evaluateChallenge(stanza.element.value, sessionObject: context.sessionObject);
        
        if mechanism!.isComplete(context.sessionObject) {
            log("Authenticated");
            context.eventBus.fire(SaslAuthSuccessEvent(sessionObject: context.sessionObject));
        } else {
            log("Authenticated by server but responses not accepted by client.");
            context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: SaslError.server_not_trusted));
        }
    }
    
    func processFailure(stanza: Stanza) {
        context.sessionObject.setProperty(SaslModule.SASL_MECHANISM, value: nil);
        let errorName = stanza.findChild()?.name;
        let error = errorName == nil ? nil : SaslError(rawValue: errorName!);
        log("Authentication failed with error:", error, errorName);
        
        context.eventBus.fire(SaslAuthFailedEvent(sessionObject: context.sessionObject, error: error ?? SaslError.not_authorized));
    }
    
    func processChallenge(stanza: Stanza) throws {
        let mechanism: SaslMechanism = context.sessionObject.getProperty(SaslModule.SASL_MECHANISM)!;
        if mechanism.isComplete(context.sessionObject) {
            throw ErrorCondition.bad_request;
        }
        let challenge = stanza.element.value;
        let response = mechanism.evaluateChallenge(challenge, sessionObject: context.sessionObject);
        let responseEl = Stanza(name: "response");
        responseEl.element.xmlns = SaslModule.SASL_XMLNS;
        responseEl.element.value = response;
        context.writer?.write(responseEl);
    }
    
    func getSupportedMechanisms() -> [String] {
        var result = [String]();
        StreamFeaturesModule.getStreamFeatures(context.sessionObject)?.findChild("mechanisms")?.forEachChild("mechanism", fn: { (mech:Element) -> Void in
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
    public class SaslAuthFailedEvent: Event {
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
    public class SaslAuthStartEvent: Event {
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
    public class SaslAuthSuccessEvent: Event {
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