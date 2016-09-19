//
// Criteria.swift
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
 Instance of this class are used to build `Element` matching mechanism which is used 
 ie. by `XmppModulesManager` to select `XmppModule` instances which should process 
 particular element.
 */
open class Criteria {
    
    /// Creates empty criteria - will never match
    open static func empty() -> Criteria {
        return Criteria(defValue:false);
    }
    
    /// Creates criteria which will match if any of passed criterias will match
    open static func or(_ criteria: Criteria...) -> Criteria {
        return OrImpl(criteria: criteria);
    }
    
    /**
     Creates criteria which will match element if every passed attribute matches with 
     element. If parameter is nil then it will always match.
     - parameter name: name of element
     - parameter xmlns: xmlns of element
     - parameter types: list of allowed values for `type` attribute
     - parameter containsAttribute: checks if passed attribute is set
     */
    open static func name(_ name: String, xmlns: String? = nil, types:[String]? = nil, containsAttribute: String? = nil) -> Criteria {
        return ElementCriteria(name: name, xmlns: xmlns, types: types, attributes: nil, containsAttribute: containsAttribute);
    }

    /**
     Creates criteria which will match element if every passed attribute matches with
     element. If parameter is nil then it will always match.
     - parameter name: name of element
     - parameter xmlns: xmlns of element
     - parameter types: list of allowed values for `type` attribute
     - parameter containsAttribute: checks if passed attribute is set
     */
    open static func name(_ name: String, xmlns: String? = nil, types:[StanzaType], containsAttribute: String? = nil) -> Criteria {
        let typesStr = types.map { (type) -> String in
            return type.rawValue;
        }
        return ElementCriteria(name: name, xmlns: xmlns, types: typesStr, attributes: nil, containsAttribute: containsAttribute);
    }
    
    /**
     Creates criteria which will match element if every passed attribute matches with
     element. If parameter is nil then it will always match.
     - parameter name: name of element
     - parameter attributes: dictionary of attributes and values which needs to match
     */
    open static func name(_ name:String?, attributes:[String:String]) -> Criteria {
        return ElementCriteria(name: name, attributes: attributes);
    }
    
    /**
     Creates criteria which will match element if every passed attribute matches with
     element. If parameter is nil then it will always match.
     - parameter xmlns: xmlns of element
     - parameter containsAttribute: checks if passed attribute is set
     */
    open static func xmlns(_ xmlns:String, containsAttribute: String? = nil) -> Criteria {
        return ElementCriteria(xmlns: xmlns, attributes: nil, containsAttribute: containsAttribute);
    }
    
    fileprivate var nextCriteria:Criteria?;
    
    fileprivate let defValue:Bool;
    
    fileprivate init() {
        defValue = true;
    }
    
    fileprivate init(defValue:Bool) {
        self.defValue = defValue;
    }
    
    /**
     Added additional criterial to check on subelements
     */
    open func add(_ crit:Criteria) -> Criteria {
        if (nextCriteria == nil) {
            nextCriteria = crit;
        } else {
            _ = nextCriteria?.add(crit);
        }
        return self;
    }
    
    /**
     Checks if element matches (checks subelements if additional criteria are added)
     - returns: true - if element matches
     */
    open func match(_ elem:Element) -> Bool {
        if (nextCriteria == nil) {
            return defValue;
        }
        var result = false;
        for child in elem.getChildren() {
            if (nextCriteria!.match(child)) {
                result = true;
                break;
            }
        }
        return result;
    }
    
    /// Internal implementation used to match elements
    class ElementCriteria: Criteria {
        
        let name:String?;
        let xmlns:String?;
        let attributes:[String:String]?;
        let types:[String]?;
        let containsAttribute: String?;
        
        init(name: String? = nil, xmlns: String? = nil, types:[String]? = nil, attributes:[String:String]?, containsAttribute: String? = nil) {
            self.name = name;
            self.xmlns = xmlns;
            self.types = types;
            self.attributes = attributes;
            self.containsAttribute = containsAttribute;
            super.init();
        }
        
        override func match(_ elem: Element) -> Bool {
            var match = true;
            if (name != nil) {
                match = match && (name == elem.name);
            }
            if (xmlns != nil) {
                match = match && (xmlns == elem.xmlns);
            }
            if (types != nil) {
                let type = elem.getAttribute("type") ?? "";
                match = match && (types?.index(of: type) != nil);
            }
            if (attributes != nil) {
                for (k,v) in self.attributes! {
                    match = match && (v == elem.getAttribute(k));
                    if (!match) {
                        return false;
                    }
                }
            }
            if (containsAttribute != nil) {
                match = match && elem.getAttribute(containsAttribute!) != nil;
            }
            return match && super.match(elem);
        }
        
    }
    
    /// Internal implementation used for 'or' matching
    class OrImpl: Criteria {
        let criteria:Array<Criteria>!;
        
        init(criteria:Array<Criteria>) {
            self.criteria = criteria;
            super.init(defValue: false);
        }
        
        override func match(_ elem: Element) -> Bool {
            for crit in self.criteria {
                if (crit.match(elem)) {
                    return true;
                }
            }
            return super.match(elem);
        }
    }
}
