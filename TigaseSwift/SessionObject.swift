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

public class SessionObject {
    
    public static let PASSWORD = "password";
    
    public static let RESOURCE = "resource";
    
    public static let USER_BARE_JID = "userBareJid";
    
    public static let STARTTLS_ACTIVE = "starttls#active";
    
    public static let STARTTLS_DISLABLED = "starttls#disabled";
    
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
    
    var properties = [String:Entry]();
    
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
}
