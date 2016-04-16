//
// XmppModulesManager.swift
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

public class XmppModulesManager : ContextAware {
    
    public var context:Context!;
    
    private var modules = [XmppModule]();
    
    private var modulesById = [String:XmppModule]();
    
    init() {
    }
    
    public var availableFeatures:Set<String> {
        var result = Set<String>();
        for module in self.modules {
            result.unionInPlace(module.features);
        }
        return result;
    }
    
    public func findModules(stanza:Stanza) -> [XmppModule] {
        return findModules(stanza.element);
    }
    
    public func findModules(elem:Element) -> [XmppModule] {
        var results = [XmppModule]();
        for module in modules {
            if module.criteria.match(elem) {
                results.append(module);
            }
        }
        return results;
    }
    
    public func getModule<T:XmppModule>(id:String) -> T? {
        return modulesById[id] as? T;
    }
    
    public func register<T:XmppModule>(module:T) -> T {
        if var contextAware = module as? ContextAware {
            contextAware.context = context;
        }
        
        modulesById[module.id] = module;
        modules.append(module);
        return module;
    }
    
    public func unregister<T:XmppModule>(module:T) -> T {
        modulesById.removeValueForKey(module.id)
        if let idx = self.modules.indexOf({ $0 === module}) {
            self.modules.removeAtIndex(idx);
        }
        return module;
    }
    
}