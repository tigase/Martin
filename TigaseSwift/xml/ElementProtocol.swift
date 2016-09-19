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
public protocol ElementProtocol {
    
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
    func findChild(_ name:String?, xmlns:String?) -> Element?;
    /**
     Find child elements matching name and xmlns
     - parameter name: name of element
     - parameter xmlns: xmlns of element
     - returns: array of matching child elements
     */
    func getChildren(_ name:String?, xmlns:String?) -> Array<Element>;
    /**
     Get value for attribute
     - parameter key: attribute
     - returns: value for attibutes
     */
    func getAttribute(_ key:String) -> String?;
    /**
     Remove element from child elements
     - parameter child: element to remove
     */
    func removeChild(_ child: Element);
    /**
     Set value for attribute
     - parameter key: attribute
     - parameter value: value to set
     */
    func setAttribute(_ key:String, value:String?);
    
}
