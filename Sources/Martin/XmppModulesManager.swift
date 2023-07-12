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

public struct XmppModuleIdentifier<T: XmppModule> {
    
    public var id: String {
        return T.ID;
    }

    public init() {}
    
}


/**
 Class responsible for storing instances of `XmppModule` and returning
 instances of `XmppModule` which are registered for processing particular
 stanza.
 */
public class XmppModulesManager : ContextAware, Resetable {
        
    open weak var context: Context?;
    
    private var _modules: [XmppModule] = [];
    private var _processors: [XmppStanzaProcessor] = [];
    
    /// List of registered modules
    public var modules: [XmppModule] {
        get {
            return lock.with {
                return _modules;
            }
        }
    }
    
    /// List of registered processors
    public var processors: [XmppStanzaProcessor] {
        get {
            return lock.with {
                return _processors;
            }
        }
    }
    /// Map of registered modules where module id is key - used for fast retrieval of module instances
    private var modulesById = [String:XmppModule]();
    
    private let lock = UnfairLock();
    
    init() {
    }
    
    deinit {
        for module in modules {
            if let contextAware = module as? ContextAware {
                contextAware.context = nil;
            }
        }
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
    open func findProcessors(for stanza:Stanza) -> [XmppStanzaProcessor] {
        return processors.filter({ $0.criteria.match(stanza.element) })
    }
    
    open func module<T: XmppModule>(_ identifier: XmppModuleIdentifier<T>) -> T {
        return modulesById[identifier.id]! as! T;
    }

    open func moduleOrNil<T: XmppModule>(_ identifier: XmppModuleIdentifier<T>) -> T? {
        return modulesById[identifier.id] as? T
    }

    open func module<T: XmppModule>(_ type: T.Type) -> T {
        return modulesById[type.ID]! as! T;
    }

    open func moduleOrNil<T: XmppModule>(_ type: T.Type) -> T? {
        return modulesById[type.ID] as? T;
    }

    open func modules<T>(_ type: T.Type) -> [T] {
        return modulesById.values.compactMap({ $0 as? T });
    }
    
    open func hasModule(_ type: XmppModule.Type) -> Bool {
        return modulesById[type.ID] != nil;
    }

    open func hasModule<T:XmppModule>(_ identifier: XmppModuleIdentifier<T>) -> Bool {
        return modulesById[identifier.id] != nil;
    }
    
    /// Method resets registered modules internal state
    open func reset(scopes: Set<ResetableScope>) {
        for module in modules {
            if let resetable = module as? Resetable {
                resetable.reset(scopes: scopes);
            }
        }
    }
    
    /**
     Register passed instance of module and return it.
     - parameter module: instance of `XmppModule` to register
     - returns: same instace as passed in parameter `module`
     */
    @discardableResult
    open func register<T:XmppModule>(_ module:T) -> T {
        if let contextAware = module as? ContextAware {
            contextAware.context = context;
        }

        return lock.with {
            modulesById[T.ID] = module;
            _modules.append(module);
            if let processor = module as? XmppStanzaProcessor {
                _processors.append(processor);
            }
            return module;
        }
    }
    
    /**
     Unregister passed instance of module and return it.
     - parameter module: instance of `XmppModule` to unregister
     - returns: same instace as passed in parameter `module`
     */
    @discardableResult
    open func unregister<T:XmppModule>(_ module:T) -> T {
        defer {
            if let contextAware = module as? ContextAware {
                contextAware.context = nil;
            }
        }
        return lock.with {
            modulesById.removeValue(forKey: T.ID)
            _modules.removeAll(where: { $0 === module })
            if let processor = module as? XmppStanzaProcessor {
                _processors.removeAll(where: { $0 === processor });
            }
            return module;
        }
    }
    
}
