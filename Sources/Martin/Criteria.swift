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
 This enum is used to build `Element` matching mechanism which is used
 ie. by `XmppModulesManager` to select `XmppModule` instances which should process 
 particular element.
 */
public enum Criteria: CustomDebugStringConvertible {
    /// Always returns flase
    case `false`
    /**
     Check that all conditions are met
     - parameter predicates: Conditions to check
     */
    case and([Criteria])
    /**
     Check that at least 1 condition is met
     - parameter predicates: Conditions to check
     */
    case or([Criteria])
    /**
     Check if element name matches passed value
     - parameter value: Element name
     */
    case name(String)
    /**
     Check if element XMLNS matches passed value
     - parameter xmlns: Element XMLNS
     */
    case xmlns(String)
    /**
     Check if stanza types matches passed value
     - parameter stanzaType: Value to compare
     */
    case stanzaType(StanzaType?)
    /**
     Check if element has attribute
     - parameter name: Name of the attribute
     */
    case hasAttribute(String)
    /**
     Check if any child matches
     - parameter criteria: Condition to check
     */
    indirect case then(Criteria)
    
    public var debugDescription: String {
        switch self {
        case .false:
            return "false"
        case .and(let predicates):
            return "(\(predicates.map({ "\($0.debugDescription)" }).joined(separator: " and ")))";
        case .or(let predicates):
            return "(\(predicates.map({ "\($0.debugDescription)" }).joined(separator: " or ")))";
        case .name(let name):
            return "name=\(name)";
        case .xmlns(let xmlns):
            return "xmlns=\(xmlns)";
        case .stanzaType(let type):
            return "stanzaType=\(type?.rawValue ?? "nil")";
        case .hasAttribute(let name):
            return "hasAttribute(\(name))"
        case .then(let criteria):
            return "child(\(criteria.debugDescription))";
        }
    }
    
    public func match(_ elem: Element) -> Bool {
        switch self {
        case .false:
            return false;
        case .and(let array):
            return array.allSatisfy({ $0.match(elem) })
        case .or(let array):
            return array.contains(where: { $0.match(elem) })
        case .name(let name):
            return elem.name == name;
        case .xmlns(let xmlns):
            return elem.xmlns == xmlns;
        case .stanzaType(let type):
            return elem.attribute("type") == type?.rawValue;
        case .hasAttribute(let name):
            return elem.attribute(name) != nil;
        case .then(let criteria):
            return elem.hasChild(where: criteria.match(_:));
        }
    }
}


// Helper functions for criteria
extension Criteria {
    
    public static func empty() -> Criteria {
        return .false;
    }
    
    /**
      Check that all conditions are met
     - parameter predicates: Conditions to check
     */
    public static func and(_ predicates: Criteria...) -> Criteria {
        return .and(predicates);
    }

    /**
      Check that at least on of conditions is met
     - parameter predicates: Conditions to check
     */
    public static func or(_ predicates: Criteria...) -> Criteria {
        return .or(predicates);
    }

    /**
      Create condition matching passed parameters
     - parameter name: Element name
     - parameter xmlns: Element XMLNS
     - parameter types: List of accepted stanza types
     - parameter containsAttributes: Name of attribute which element has to contain
     */
    public static func name(_ name: String, xmlns: String, types:[StanzaType?] = [], containsAttribute: String? = nil) -> Criteria {
        var predicates: [Criteria] = [.name(name), .xmlns(xmlns)];
        
        if !types.isEmpty {
            predicates.append(.or(types.map({ .stanzaType($0) })));
        }
        
        if let attribute = containsAttribute {
            predicates.append(.hasAttribute(attribute));
        }
        
        if predicates.count == 1 {
            return predicates[0];
        }
        return .and(predicates);
    }
    
    /**
      Create condition matching passed parameters
     - parameter name: Element name
     - parameter types: List of accepted stanza types
     - parameter containsAttributes: Name of attribute which element has to contain
     */
    public static func name(_ name: String, types:[StanzaType?], containsAttribute: String? = nil) -> Criteria {
        var predicates: [Criteria] = [.name(name), .or(types.map({ .stanzaType($0) }))];
        if let attribute = containsAttribute {
            predicates.append(.hasAttribute(attribute));
        }
        return .and(predicates);
    }
    
    /**
      Create condition matching passed parameters
     - parameter name: Element name
     - parameter containsAttributes: Name of attribute which element has to contain
     */
    public static func name(_ name: String, containsAttribute: String) -> Criteria {
        return .and([.name(name), .hasAttribute(containsAttribute)]);
    }
    
    /**
      Create condition checking child elements
     - parameter criteria: Condition to check agaist children
     */
    public func then(_ criteria: Criteria) -> Criteria {
        return .and([self, .then(criteria)]);
    }

    /**
     Added additional criterial to check on subelements
     - parameter criteria: Condition to check agaist children
     */
    public func add(_ criteria: Criteria) -> Criteria {
        return .and([self, .then(criteria)]);
    }
    
}
