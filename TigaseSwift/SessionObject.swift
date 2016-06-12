//
// SessionObject.swift
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

public class SessionObject: Logger {
    
    public static let DOMAIN_NAME = "domainName";
    
    public static let NICKNAME = "nickname";
    
    public static let PASSWORD = "password";
    
    public static let RESOURCE = "resource";
    
    public static let USER_BARE_JID = "userBareJid";
    
    public static let STARTTLS_ACTIVE = "starttls#active";
    
    public static let STARTTLS_DISLABLED = "starttls#disabled";
    
    public static let COMPRESSION_ACTIVE = "compression#active";
    
    public static let COMPRESSION_DISABLED = "compression#disabled";
    
    public enum Scope {
        case session
        case stream
        case user
    }
    
    class Entry {
        var scope:Scope!;
        var value:Any!;
        
        init(scope:Scope, value:Any) {
            self.scope = scope;
            self.value = value;
        }
    }
    
    private let eventBus: EventBus;
    private var properties = [String:Entry]();
    
    public var userBareJid: BareJID? {
        get {
            return self.getProperty(SessionObject.USER_BARE_JID);
        }
    }
    
    public var domainName: String? {
        get {
            return userBareJid?.domain ?? getProperty(SessionObject.DOMAIN_NAME);
        }
    }
    
    public init(eventBus:EventBus) {
        self.eventBus = eventBus;
    }
    
    public func clear(scopes scopes_:Scope...) {
        var scopes = scopes_;
        if scopes.isEmpty {
            scopes.append(Scope.session);
            scopes.append(Scope.stream);
        }
        log("removing properties for scopes", scopes);
        for (k,v) in properties {
            if (scopes.indexOf({ $0 == v.scope }) != nil) {
                properties.removeValueForKey(k);
            }
        }
        
        eventBus.fire(ClearedEvent(sessionObject: self, scopes: scopes));
    }
    
    public func hasProperty(prop:String, scope:Scope? = nil) -> Bool {
        let e = self.properties[prop];
        return e != nil && (scope == nil || e?.scope == scope);
    }
    
    public func getProperty<T>(prop:String, defValue:T, scope:Scope? = nil) -> T {
        return getProperty(prop, scope: scope) ?? defValue;
    }

    public func getProperty<T>(prop:String, scope:Scope? = nil) -> T? {
        let e = self.properties[prop];
        if (e == nil) {
            return nil;
        }
        if (scope == nil || e!.scope == scope!) {
            return e!.value as? T;
        }
        return nil;
    }
    
    public func setProperty(prop:String, value:Any?, scope:Scope = Scope.session) {
        if (value == nil) {
            self.properties.removeValueForKey(prop);
            return;
        }
        self.properties[prop] = Entry(scope:scope, value: value!)
    }
    
    public func setUserProperty(prop:String, value:Any?) {
        self.setProperty(prop, value: value, scope: Scope.user)
    }
    
    public class ClearedEvent: Event {
        public static let TYPE = ClearedEvent();
        
        public let type = "ClearedEvent";
        
        public let sessionObject:SessionObject!;
        public let scopes:[Scope]!;
        
        private init() {
            self.sessionObject = nil;
            self.scopes = nil;
        }
        
        public init(sessionObject:SessionObject, scopes:[Scope]) {
            self.sessionObject = sessionObject;
            self.scopes = scopes;
        }
    }
}
