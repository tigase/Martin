//
// ElementProtocol.swift
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
 Common protocol for classes representing `Element`
 */
public protocol ElementProtocol: CustomStringConvertible {
    
    /// Name of element
    var name:String { get }
    /// XMLNS of element
    var xmlns:String? { get }

    /**
     Add child element
     - parameter child: element to add as subelement
     */
    func addChild(_ child: Element);
    /**
     Find child element with matching name and xmlns
     - parameter name: name of element to find
     - parameter xmlns: xmlns of element to find
     - returns: first found element if any
     */
    @available(*, deprecated, renamed: "firstChild")
    func findChild(name: String?, xmlns: String?) -> Element?;
    /**
     In subelements finds element for which passed closure returns true
     - parameter where: element matcher
     - returns: first element which matches
     */
    @available(*, deprecated, renamed: "firstChild")
    func findChild(where: (Element)->Bool) -> Element?;
    
    /**
     Finds first index at which this child is found (comparison by reference).
     - returns: first index at which element was found if any
     */
    @available(*, deprecated, message: "Method will be removed")
    func firstIndex(ofChild child: Element) -> Int?;
    
    /**
     Find child elements matching name and xmlns
     - parameter name: name of element
     - parameter xmlns: xmlns of element
     - returns: array of matching child elements
     */
    @available(*, deprecated, renamed: "filterChildren")
    func getChildren(name: String?, xmlns: String?) -> Array<Element>;
    /**
     Finds every child element for which matcher returns true
     - parameter where: matcher closure
     - returns: array of matching elements
     */
    @available(*, deprecated, renamed: "filterChildren")
    func getChildren(where: (Element)->Bool) -> Array<Element>;
    /**
     Get value for attribute
     - parameter key: attribute
     - returns: value for attibutes
     */
    @available(*, deprecated, renamed: "attribute(_:)")
    func getAttribute(_ key:String) -> String?;
    /**
     Remove element from child elements (reference comparison)
     - parameter child: element to remove
     */
    func removeChild(_ child: Element);
    /**
     Remove mathing elements from child elements
     - parameter where: matcher closure
     */
    func removeChildren(where: (Element)->Bool);
    /**
     Set value for attribute
     - parameter key: attribute
     - parameter value: value to set
     */
    @available(*, deprecated, renamed: "attribute(_:newValue:)")
    func setAttribute(_ key: String, value: String?);
    
}

extension ElementProtocol {
    
    public func attribute(_ key: String, newValue: String?) {
        setAttribute(key, value: newValue);
    }
    
    public func attribute(_ key:String) -> String? {
        return getAttribute(key);
    }

    
    public func firstChild(where body: (Element)->Bool) -> Element? {
        return findChild(where: body);
    }
    
    public func firstChild(name: String, xmlns: String? = nil) -> Element? {
        return firstChild(where: { $0.name == name && (xmlns == nil || $0.xmlns == xmlns) });
    }

    public func firstChild(xmlns: String) -> Element? {
        return firstChild(where: { $0.xmlns == xmlns })
    }

    public func filterChildren(where body: (Element)->Bool) -> Array<Element> {
        return getChildren(where: body);
    }

    public func filterChildren(name: String, xmlns: String?) -> Array<Element> {
        filterChildren(where: { $0.name == name && (xmlns == nil || $0.xmlns == xmlns) });
    }

    public func removeChildren(name: String, xmlns: String? = nil) {
        removeChildren(where: { $0.name == name && (xmlns == nil || $0.xmlns == xmlns) });
    }

    func hasChild(name: String? = nil, xmlns: String? = nil) -> Bool {
        return findChild(name: name, xmlns: xmlns) != nil;
    }
    
}
