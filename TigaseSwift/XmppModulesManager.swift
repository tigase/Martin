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

/**
 Class responsible for storing instances of `XmppModule` and returning
 instances of `XmppModule` which are registered for processing particular
 stanza.
 */
public class XmppModulesManager : ContextAware {
    
    public var context:Context!;
    
    /// List of registered instances of `XmppStanzaFilter` which needs to process packets
    public var filters = [XmppStanzaFilter]();
    
    /// List of instances `Initializable` which require initialization
    private var initializationRequired = [Initializable]();
    
    /// List of registered modules
    private var modules = [XmppModule]();
    /// Map of registered modules where module id is key - used for fast retrieval of module instances
    private var modulesById = [String:XmppModule]();
    
    init() {
    }
    
    /// Returns list of features provided by registered `XmppModule` instances
    public var availableFeatures:Set<String> {
        var result = Set<String>();
        for module in self.modules {
            result.unionInPlace(module.features);
        }
        return result;
    }
    
    /**
     Processes passed stanza and return list of `XmppModule` instances which should process this stanza.
     Instances of `XmppModule` are selected by checking if it's `criteria` field matches stanza.
     */
    public func findModules(stanza:Stanza) -> [XmppModule] {
        return findModules(stanza.element);
    }
    
    /**
     Processes passed element and return list of `XmppModule` instances which should process this element.
     Instances of `XmppModule` are selected by checking if it's `criteria` field matches element.
     */
    public func findModules(elem:Element) -> [XmppModule] {
        var results = [XmppModule]();
        for module in modules {
            if module.criteria.match(elem) {
                results.append(module);
            }
        }
        return results;
    }
    
    /// Returns instance of `XmppModule` registered under passed id
    public func getModule<T:XmppModule>(id:String) -> T? {
        return modulesById[id] as? T;
    }
    
    public func initIfRequired() {
        initializationRequired.forEach { (module) in
            module.initialize();
        }
    }
    
    /**
     Register passed instance of module and return it.
     - parameter module: instance of `XmppModule` to register
     - returns: same instace as passed in parameter `module`
     */
    public func register<T:XmppModule>(module:T) -> T {
        if var contextAware = module as? ContextAware {
            contextAware.context = context;
        }
        
        modulesById[module.id] = module;
        modules.append(module);
        if let initModule = module as? Initializable {
            initializationRequired.append(initModule);
        }
        if let filter = module as? XmppStanzaFilter {
            filters.append(filter);
        }
        return module;
    }
    
    /**
     Unregister passed instance of module and return it.
     - parameter module: instance of `XmppModule` to unregister
     - returns: same instace as passed in parameter `module`
     */
    public func unregister<T:XmppModule>(module:T) -> T {
        modulesById.removeValueForKey(module.id)
        if let idx = self.modules.indexOf({ $0 === module}) {
            self.modules.removeAtIndex(idx);
        }
        if let initModule = module as? Initializable {
            if let idx = self.initializationRequired.indexOf({ $0 === initModule }) {
                self.initializationRequired.removeAtIndex(idx);
            }
        }
        if let filter = module as? XmppStanzaFilter {
            if let idx = self.filters.indexOf({ $0 === filter }) {
                self.filters.removeAtIndex(idx);
            }
        }
        return module;
    }
    
}