//
// CData.swift
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
 Class responsible for holding cdata values found in parsed XML in element
 */
open class CData : Node {
    
    /// cdata
    open var value:String;
    
    init(value:String) {
        self.value = value
    }
    
    override open var stringValue: String {
        return EscapeUtils.escape(value);
    }
    
    override open func toPrettyString() -> String {
        return EscapeUtils.escape(value);
    }
    
}

public func ==(lhs: CData, rhs: CData) -> Bool {
    return lhs.value == rhs.value;
}
