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
open class XmppModulesManager : ContextAware {
    
    open var context:Context!;
    
    /// List of registered instances of `XmppStanzaFilter` which needs to process packets
    open var filters = [XmppStanzaFilter]();
    
    /// List of instances `Initializable` which require initialization
    fileprivate var initializationRequired = [Initializable]();
    
    /// List of registered modules
    fileprivate var modules = [XmppModule]();
    /// Map of registered modules where module id is key - used for fast retrieval of module instances
    fileprivate var modulesById = [String:XmppModule]();
    
    init() {
    }
    
    /// Returns list of features provided by registered `XmppModule` instances
    open var availableFeatures:Set<String> {
        var result = Set<String>();
        for module in self.modules {
            result.formUnion(module.features);
        }
        return result;
    }
    
    /**
     Processes passed stanza and return list of `XmppModule` instances which should process this stanza.
     Instances of `XmppModule` are selected by checking if it's `criteria` field matches stanza.
     */
    open func findModules(for stanza:Stanza) -> [XmppModule] {
        return findModules(for: stanza.element);
    }
    
    /**
     Processes passed element and return list of `XmppModule` instances which should process this element.
     Instances of `XmppModule` are selected by checking if it's `criteria` field matches element.
     */
    open func findModules(for elem:Element) -> [XmppModule] {
        var results = [XmppModule]();
        for module in modules {
            if module.criteria.match(elem) {
                results.append(module);
            }
        }
        return results;
    }
    
    /// Returns instance of `XmppModule` registered under passed id
    open func getModule<T:XmppModule>(_ id:String) -> T? {
        return modulesById[id] as? T;
    }
    
    open func initIfRequired() {
        initializationRequired.forEach { (module) in
            module.initialize();
        }
    }
    
    /**
     Register passed instance of module and return it.
     - parameter module: instance of `XmppModule` to register
     - returns: same instace as passed in parameter `module`
     */
    open func register<T:XmppModule>(_ module:T) -> T {
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
    open func unregister<T:XmppModule>(_ module:T) -> T {
        modulesById.removeValue(forKey: module.id)
        if let idx = self.modules.index(where: { $0 === module}) {
            self.modules.remove(at: idx);
        }
        if let initModule = module as? Initializable {
            if let idx = self.initializationRequired.index(where: { $0 === initModule }) {
                self.initializationRequired.remove(at: idx);
            }
        }
        if let filter = module as? XmppStanzaFilter {
            if let idx = self.filters.index(where: { $0 === filter }) {
                self.filters.remove(at: idx);
            }
        }
        if var contextAware = module as? ContextAware {
            contextAware.context = nil;
        }
        return module;
    }
    
}
