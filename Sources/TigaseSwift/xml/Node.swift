//
// Node.swift
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
 Base class used to represent parsed XML.
 */
open class Node: StringValue {
    
    open var description: String {
        return stringValue;
    }
    
    /// returns serialized value
    open var stringValue:String {
        return "Node";
    }
    
    /// returns serialized value in form easier to read
    open func toPrettyString(secure: Bool) -> String {
        return "Node";
    }
}

public func ==(lhs: Node, rhs: Node) -> Bool {
    if (lhs is Element && rhs is Element) {
        return (lhs as! Element) == (rhs as! Element);
    } else if (lhs is CData && rhs is CData) {
        return (lhs as! CData) == (rhs as! CData);
    }
    return false;
}
