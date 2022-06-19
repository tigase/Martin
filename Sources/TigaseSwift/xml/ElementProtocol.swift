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
public protocol ElementProtocol: CustomStringConvertible, CustomDebugStringConvertible {
    
    /// Name of element
    var name:String { get }
    /// XMLNS of element
    var xmlns:String? { get }
    var attributes: [String: String] { get }
    var children: [Element] { get }
    
    /**
     Add child element
     - parameter child: element to add as subelement
     */
    func addChild(_ child: Element);
    /**
     In subelements finds element for which passed closure returns true
     - parameter where: element matcher
     - returns: first element which matches
     */
    func firstChild(where: (Element)->Bool) -> Element?;

    /**
     Find child matching elements
     - parameter where: matcher closure
     - returns: array of matching child elements
     */
    func filterChildren(where: (Element)->Bool) -> Array<Element>
    
    /**
     Get value for attribute
     - parameter key: attribute
     - returns: value for attibutes
     */
    func attribute(_ key:String) -> String?;
    /**
     Set value for attribute
     - parameter key: attribute
     - parameter newValue: value to set
     */
    func attribute(_ key: String, newValue: String?);

    /**
     Remove attribute
     - parameter key: attribute
     */
    func removeAttribute(_ key: String);
    
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
    
}

extension ElementProtocol {
    
    public func hasChild(name: String, xmlns: String? = nil) -> Bool {
        return firstChild(name: name, xmlns: xmlns) != nil;
    }
    
    public func compactMapChildren<T>(_ transform: (Element)->T?) -> Array<T> {
        return children.compactMap(transform);
    }

    /**
     Find child element with matching name and xmlns
     - parameter name: name of element to find
     - parameter xmlns: xmlns of element to find
     - returns: first found element if any
     */
    public func firstChild(name: String, xmlns: String? = nil) -> Element? {
        return firstChild(where: { $0.name == name && (xmlns == nil || $0.xmlns == xmlns) });
    }
    /**
     In subelements finds element for which passed closure returns true
     - parameter where: element matcher
     - returns: first element which matches
     */
    public func firstChild(xmlns: String) -> Element? {
        return firstChild(where: { $0.xmlns == xmlns })
    }

    /**
     Find child elements matching name and xmlns
     - parameter name: name of element
     - parameter xmlns: xmlns of element
     - returns: array of matching child elements
     */
    public func filterChildren(name: String, xmlns: String? = nil) -> Array<Element> {
        filterChildren(where: { $0.name == name && (xmlns == nil || $0.xmlns == xmlns) });
    }
    
    /**
     Find child elements matching name and xmlns
     - parameter xmlns: xmlns of element
     - returns: array of matching child elements
     */
    public func filterChildren(xmlns: String) -> Array<Element> {
        filterChildren(where: { $0.xmlns == xmlns });
    }
    
    /**
     Remove mathing elements from child elements
     - parameter name: element name
     - parameter xmlns: element xmlns
     */
    public func removeChildren(name: String, xmlns: String? = nil) {
        removeChildren(where: { $0.name == name && (xmlns == nil || $0.xmlns == xmlns) });
    }

    /**
     Remove mathing elements from child elements
     - parameter xmlns: element name
     */
    public func removeChildren(xmlns: String) {
        removeChildren(where: { $0.xmlns == xmlns });
    }

    /**
     Remove all child elements
     */
    public func removeAllChildren() {
        removeChildren(where: { _ in true });
    }

}
