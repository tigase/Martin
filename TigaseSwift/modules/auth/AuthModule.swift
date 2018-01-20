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
open class AuthModule: Logger, XmppModule, ContextAware, EventHandler {
    /// ID of module for lookup in `XmppModulesManager`
    open static let ID = "auth";
    open static let AUTHORIZED = "authorized";
    open static let CREDENTIALS_CALLBACK = "credentialsCallback";
    open static let LOGIN_USER_NAME_KEY = "LOGIN_USER_NAME";
    
    open let id = ID;
    
    fileprivate var _context:Context!;
    open var context:Context! {
        get {
            return _context;
        }
        set {
            if newValue == nil {
                _context.eventBus.unregister(handler: self, for: SaslModule.SaslAuthSuccessEvent.TYPE, SaslModule.SaslAuthStartEvent.TYPE, SaslModule.SaslAuthFailedEvent.TYPE);
            } else {
                newValue.eventBus.register(handler: self, for: SaslModule.SaslAuthSuccessEvent.TYPE, SaslModule.SaslAuthStartEvent.TYPE, SaslModule.SaslAuthFailedEvent.TYPE);
            }
            _context = newValue;
        }
    }
    
    open let criteria = Criteria.empty();
    
    open let features = [String]();
    
    open var inProgress: Bool {
        return context.sessionObject.getProperty("AUTH_IN_PROGRESS", defValue: false);
    }
    
    public override init() {
        
    }
    
    open func process(stanza: Stanza) throws {
        
    }
    
    /**
     Starts authentication process using other module providing 
     mechanisms for authentication
     */
    open func login() {
        if let saslModule:SaslModule = _context.modulesManager.getModule(SaslModule.ID) {
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
            _context.sessionObject.setProperty("AUTH_IN_PROGRESS", value: false);
            saslEvent.sessionObject.setProperty(AuthModule.AUTHORIZED, value: true, scope: SessionObject.Scope.stream);
            _context.eventBus.fire(AuthSuccessEvent(sessionObject: saslEvent.sessionObject));
        case is SaslModule.SaslAuthFailedEvent:
            let saslEvent = event as! SaslModule.SaslAuthFailedEvent;
            saslEvent.sessionObject.setProperty(AuthModule.AUTHORIZED, value: false, scope: SessionObject.Scope.stream);
            _context.eventBus.fire(AuthFailedEvent(sessionObject: saslEvent.sessionObject, error: saslEvent.error));
        case is SaslModule.SaslAuthStartEvent:
            let saslEvent = event as! SaslModule.SaslAuthStartEvent;
            _context.sessionObject.setProperty("AUTH_IN_PROGRESS", value: true);
            _context.eventBus.fire(AuthStartEvent(sessionObject: saslEvent.sessionObject));
        default:
            log("handing of unsupported event", event);
        }
    }
    
    /// Event fired on authentication failure
    open class AuthFailedEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = AuthFailedEvent();
        
        open let type = "AuthFailedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        /// Error returned by server during authentication
        open let error:SaslError!;
        
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
    open class AuthStartEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = AuthStartEvent();
        
        open let type = "AuthStartEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
    }
    
    open class AuthFinishExpectedEvent: Event {
        
        open static let TYPE = AuthFinishExpectedEvent();
        
        open let type = "AuthFinishExpectedEvent";
        
        open let sessionObject: SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
        
    }
    
    /// Event fired when after sucessful authentication
    open class AuthSuccessEvent: Event {
        /// Identifier of event which should be used during registration of `EventHandler`
        open static let TYPE = AuthSuccessEvent();
        
        open let type = "AuthSuccessEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        open let sessionObject:SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
    }
}
