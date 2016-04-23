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

public class Criteria {
    
    public static func empty() -> Criteria {
        return Criteria(defValue:false);
    }
    
    public static func or(criteria: Criteria...) -> Criteria {
        return OrImpl(criteria: criteria);
    }
    
    public static func name(name: String, xmlns: String? = nil, types:[String]? = nil) -> Criteria {
        return ElementCriteria(name: name, xmlns: xmlns, types: types, attributes: nil);
    }

    public static func name(name: String, xmlns: String? = nil, types:[StanzaType]) -> Criteria {
        var typesStr = types.map { (type) -> String in
            return type.rawValue;
        }
        return ElementCriteria(name: name, xmlns: xmlns, types: typesStr, attributes: nil);
    }
    
    public static func name(name:String?, attributes:[String:String]) -> Criteria {
        return ElementCriteria(name: name, attributes: attributes);
    }
    
    public static func xmlns(xmlns:String) -> Criteria {
        return ElementCriteria(xmlns: xmlns, attributes: nil);
    }
    
    private var nextCriteria:Criteria?;
    
    private let defValue:Bool;
    
    private init() {
        defValue = true;
    }
    
    private init(defValue:Bool) {
        self.defValue = defValue;
    }
    
    public func add(crit:Criteria) -> Criteria {
        if (nextCriteria == nil) {
            nextCriteria = crit;
        } else {
            nextCriteria?.add(crit);
        }
        return self;
    }
    
    public func match(elem:Element) -> Bool {
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
    
    class ElementCriteria: Criteria {
        
        let name:String?;
        let xmlns:String?;
        let attributes:[String:String]?;
        let types:[String]?;
        
        init(name: String? = nil, xmlns: String? = nil, types:[String]? = nil, attributes:[String:String]?) {
            self.name = name;
            self.xmlns = xmlns;
            self.types = types;
            self.attributes = attributes;
            super.init();
        }
        
        override func match(elem: Element) -> Bool {
            var match = true;
            if (name != nil) {
                match = match && (name == elem.name);
            }
            if (xmlns != nil) {
                match = match && (xmlns == elem.xmlns);
            }
            if (types != nil) {
                let type = elem.getAttribute("type") ?? "";
                match = match && (types?.indexOf(type) != nil);
            }
            if (attributes != nil) {
                for (k,v) in self.attributes! {
                    match = match && (v == elem.getAttribute(k));
                    if (!match) {
                        return false;
                    }
                }
            }
            return match && super.match(elem);
        }
        
    }
    
    class OrImpl: Criteria {
        let criteria:Array<Criteria>!;
        
        init(criteria:Array<Criteria>) {
            self.criteria = criteria;
            super.init(defValue: false);
        }
        
        override func match(elem: Element) -> Bool {
            for crit in self.criteria {
                if (crit.match(elem)) {
                    return true;
                }
            }
            return super.match(elem);
        }
    }
}