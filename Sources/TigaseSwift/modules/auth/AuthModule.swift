//
// AuthModule.swift
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

extension XmppModuleIdentifier {
    public static var auth: XmppModuleIdentifier<AuthModule> {
        return AuthModule.IDENTIFIER;
    }
}

/**
 Common authentication module provides generic support for authentication.
 Other authentication module (like ie. `SaslModule`) may require this
 module to work properly.
 */
open class AuthModule: XmppModuleBase, XmppModule, EventHandler, Resetable {
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "auth";
    public static let IDENTIFIER = XmppModuleIdentifier<AuthModule>();
    public static let CREDENTIALS_CALLBACK = "credentialsCallback";
    public static let LOGIN_USER_NAME_KEY = "LOGIN_USER_NAME";
    
    private let logger = Logger(subsystem: "TigaseSwift", category: "AuthModule");
        
    open weak override var context: Context? {
        didSet {
            if let context = oldValue {
                context.eventBus.unregister(handler: self, for: SaslModule.SaslAuthSuccessEvent.TYPE, SaslModule.SaslAuthStartEvent.TYPE, SaslModule.SaslAuthFailedEvent.TYPE);
            }
            if let newValue = context {
                newValue.eventBus.register(handler: self, for: SaslModule.SaslAuthSuccessEvent.TYPE, SaslModule.SaslAuthStartEvent.TYPE, SaslModule.SaslAuthFailedEvent.TYPE);
            }
        }
    }
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    open private(set) var state: AuthorizationStatus = .notAuthorized;
    
    public override init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        
    }
    
    /**
     Starts authentication process using other module providing 
     mechanisms for authentication
     */
    open func login() {
        if let saslModule = context?.modulesManager.moduleOrNil(.sasl) {
            saslModule.login();
        }
    }
    
    /**
     Method handles events which needs to be processed by module
     for proper workflow.
     - parameter event: event to process
     */
    open func handle(event: Event) {
        switch event {
        case is SaslModule.SaslAuthSuccessEvent:
            let saslEvent = event as! SaslModule.SaslAuthSuccessEvent;
            self.state = .authorized;
            fire(AuthSuccessEvent(context: saslEvent.context));
        case is SaslModule.SaslAuthFailedEvent:
            let saslEvent = event as! SaslModule.SaslAuthFailedEvent;
            self.state = .notAuthorized;
            fire(AuthFailedEvent(context: saslEvent.context, error: saslEvent.error));
        case is SaslModule.SaslAuthStartEvent:
            let saslEvent = event as! SaslModule.SaslAuthStartEvent;
            self.state = .inProgress;
            fire(AuthStartEvent(context: saslEvent.context));
        default:
            logger.error("handing of unsupported event: \(event)");
        }
    }
    
    public func reset(scope: ResetableScope) {
        if scope == .session {
            state = .notAuthorized;
        } else {
            if state == .inProgress {
                state = .notAuthorized;
            }
        }
    }
    
    /// Event fired on authentication failure
    open class AuthFailedEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthFailedEvent();
        
        /// Error returned by server during authentication
        public let error:SaslError!;
        
        init() {
            error = nil;
            super.init(type: "AuthFailedEvent");
        }
        
        public init(context: Context, error: SaslError) {
            self.error = error;
            super.init(type: "AuthFailedEvent", context: context);
        }
    }
    
    /// Event fired on start of authentication process
    open class AuthStartEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthStartEvent();
                
        init() {
            super.init(type: "AuthStartEvent");
        }
        
        public init(context: Context) {
            super.init(type: "AuthStartEvent", context: context);
        }
    }
    
    open class AuthFinishExpectedEvent: AbstractEvent {
        
        public static let TYPE = AuthFinishExpectedEvent();
        
        init() {
            super.init(type: "AuthFinishExpectedEvent");
        }
        
        public init(context: Context) {
            super.init(type: "AuthFinishExpectedEvent", context: context);
        }
        
    }
    
    /// Event fired when after sucessful authentication
    open class AuthSuccessEvent: AbstractEvent {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthSuccessEvent();
        
        init() {
            super.init(type: "AuthSuccessEvent");
        }
        
        public init(context: Context) {
            super.init(type: "AuthSuccessEvent", context: context);
        }
    }
    
    public enum AuthorizationStatus {
        case notAuthorized
        case inProgress
        case authorized
    }
}
