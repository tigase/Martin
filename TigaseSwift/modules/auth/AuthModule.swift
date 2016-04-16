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

public class AuthModule: Logger, XmppModule, ContextAware, EventHandler {
    
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
    
    public func login() {
        let saslModule:SaslModule? = _context.modulesManager.getModule(SaslModule.ID);
        if saslModule != nil {
            saslModule?.login();
        }
    }
    
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
    
    public class AuthFailedEvent: Event {
        
        public static let TYPE = AuthFailedEvent();
        
        public let type = "AuthFailedEvent";
        public let sessionObject:SessionObject!;
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
    
    public class AuthStartEvent: Event {
        public static let TYPE = AuthStartEvent();
        
        public let type = "AuthStartEvent";
        public let sessionObject:SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
    }
    
    
    public class AuthSuccessEvent: Event {
        
        public static let TYPE = AuthSuccessEvent();
        
        public let type = "AuthSuccessEvent";
        public let sessionObject:SessionObject!;
        
        init() {
            sessionObject = nil;
        }
        
        public init(sessionObject: SessionObject) {
            self.sessionObject = sessionObject;
        }
    }
}