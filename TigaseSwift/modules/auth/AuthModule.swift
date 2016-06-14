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

/**
 Common authentication module provides generic support for authentication.
 Other authentication module (like ie. `SaslModule`) may require this
 module to work properly.
 */
public class AuthModule: Logger, XmppModule, ContextAware, EventHandler {
    /// ID of module for lookup in `XmppModulesManager`
    public static let ID = "auth";
    public static let AUTHORIZED = "authorized";
    public static let CREDENTIALS_CALLBACK = "credentialsCallback";
    public static let LOGIN_USER_NAME_KEY = "LOGIN_USER_NAME";
    
    public let id = ID;
    
    private var _context:Context!;
    public var context:Context! {
        get {
            return _context;
        }
        set {
            if newValue == nil {
                _context.eventBus.unregister(self, events: SaslModule.SaslAuthSuccessEvent.TYPE, SaslModule.SaslAuthStartEvent.TYPE, SaslModule.SaslAuthFailedEvent.TYPE);
            } else {
                newValue.eventBus.register(self, events: SaslModule.SaslAuthSuccessEvent.TYPE, SaslModule.SaslAuthStartEvent.TYPE, SaslModule.SaslAuthFailedEvent.TYPE);
            }
            _context = newValue;
        }
    }
    
    public let criteria = Criteria.empty();
    
    public let features = [String]();
    
    public override init() {
        
    }
    
    public func process(elem: Stanza) throws {
        
    }
    
    /**
     Starts authentication process using other module providing 
     mechanisms for authentication
     */
    public func login() {
        let saslModule:SaslModule? = _context.modulesManager.getModule(SaslModule.ID);
        if saslModule != nil {
            saslModule?.login();
        }
    }
    
    /**
     Method handles events which needs to be processed by module
     for proper workflow.
     - parameter event: event to process
     */
    public func handleEvent(event: Event) {
        switch event {
        case is SaslModule.SaslAuthSuccessEvent:
            let saslEvent = event as! SaslModule.SaslAuthSuccessEvent;
            saslEvent.sessionObject.setProperty(AuthModule.AUTHORIZED, value: true, scope: SessionObject.Scope.stream);
            _context.eventBus.fire(AuthSuccessEvent(sessionObject: saslEvent.sessionObject));
        case is SaslModule.SaslAuthFailedEvent:
            let saslEvent = event as! SaslModule.SaslAuthFailedEvent;
            saslEvent.sessionObject.setProperty(AuthModule.AUTHORIZED, value: false, scope: SessionObject.Scope.stream);
            _context.eventBus.fire(AuthFailedEvent(sessionObject: saslEvent.sessionObject, error: saslEvent.error));
        case is SaslModule.SaslAuthStartEvent:
            let saslEvent = event as! SaslModule.SaslAuthStartEvent;
            _context.eventBus.fire(AuthStartEvent(sessionObject: saslEvent.sessionObject));
        default:
            log("handing of unsupported event", event);
        }
    }
    
    /// Event fired on authentication failure
    public class AuthFailedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthFailedEvent();
        
        public let type = "AuthFailedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// Error returned by server during authentication
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
    
    /// Event fired on start of authentication process
    public class AuthStartEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthStartEvent();
        
        public let type = "AuthStartEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
    }
    
    /// Event fired when after sucessful authentication
    public class AuthSuccessEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        public static let TYPE = AuthSuccessEvent();
        
        public let type = "AuthSuccessEvent";
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