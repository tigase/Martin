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

/**
 Instances of this class keep configuration properties for connections and commonly used state values.
 */
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
    
    /**
     Possible scopes of properties stored in SessionObject instance:
     - stream: values will be removed when stream is closed or broken
     - session: values will be removed when stream is closed due to session being closed (proper XMPP stream close)
     - user: values will not be removed as are passed by user (ie. login, password, etc.)
     */
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
    
    /// Returns BareJID of user for connection
    public var userBareJid: BareJID? {
        get {
            return self.getProperty(SessionObject.USER_BARE_JID);
        }
    }
    
    /// Returns domain name of server for connection
    public var domainName: String? {
        get {
            return userBareJid?.domain ?? getProperty(SessionObject.DOMAIN_NAME);
        }
    }
    
    public init(eventBus:EventBus) {
        self.eventBus = eventBus;
    }
    
    /**
     Clears properties from matching scopes.
     - parameter scopes: remove properties for this scopes (if no scopes are passed then clears `stream` and `session` scopes
     */
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
    
    /**
     Check if following property is set for this scope
     - parameter prop: property name
     - parameter scope: scope for which to check (if nil then we check if property is set for any scope)
     - returns: true - if property is set
     */
    public func hasProperty(prop:String, scope:Scope? = nil) -> Bool {
        let e = self.properties[prop];
        return e != nil && (scope == nil || e?.scope == scope);
    }
    
    /**
     Retrieve value for property or return default value
     - parameter prop: property name
     - parameter defValue: default value to retrurn if property is not set
     - parameter scope: scope for which to return property value (for any scope if nil)
     - returns: value set for property or passed default value
     */
    public func getProperty<T>(prop:String, defValue:T, scope:Scope? = nil) -> T {
        return getProperty(prop, scope: scope) ?? defValue;
    }

    /**
     Retrieve value set for property
     - parameter prop: property name
     - parameter scope: scope for which to return property value (for any scope if nil)
     - returns: value set for property
     */
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
    
    /**
     Set property value to passed value for particular scope (`stream` by default)
     - parameter prop: property name
     - parameter value: value to set
     - parameter scope: scope for which to set value
     */
    public func setProperty(prop:String, value:Any?, scope:Scope = Scope.session) {
        if (value == nil) {
            self.properties.removeValueForKey(prop);
            return;
        }
        self.properties[prop] = Entry(scope:scope, value: value!)
    }
    
    /**
     Set property value to passed value for `user` scope
     */
    public func setUserProperty(prop:String, value:Any?) {
        self.setProperty(prop, value: value, scope: Scope.user)
    }
    
    /// Event fired when `SessionObject` instance is being cleared
    public class ClearedEvent: Event {
        /// Identified of event which should be used during registration of `EventHandler`
        public static let TYPE = ClearedEvent();
        
        public let type = "ClearedEvent";
        /// Instance of `SessionObject` allows to tell from which connection event was fired
        public let sessionObject:SessionObject!;
        /// scopes which were cleared
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
