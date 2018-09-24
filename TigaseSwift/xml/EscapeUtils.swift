//
// EscapeUtils.swift
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
 Helper class for escaping/unescaping XML entries
 */
open class EscapeUtils {
    
    fileprivate static let ENTITIES = [ [ "&", "&amp;", "&#38;"], ["<", "&lt;", "&#60;"], [">", "&gt;", "&#62;"], ["\"", "&quot;", "&#34;"], ["'", "&apos;", "&#39;"] ];
    
    /**
     Unescape string
     - parameter value: string to unescape
     - returns: unescaped string
     */
    public static func unescape(_ value:String) -> String {
        if !value.contains("&") {
            return value;
        }
        var result = value;
        var i=ENTITIES.count-1;
        while i >= 0 {
            // this is for libxml2 as it replaces every &amp; with &#38; which in XML both replaces &
            result = result.replacingOccurrences(of: ENTITIES[i][2], with: ENTITIES[i][0]);
            // this is for normal replacement (may not be needed but let's keep it for compatibility
            result = result.replacingOccurrences(of: ENTITIES[i][1], with: ENTITIES[i][0]);
            i -= 1;
        }
        return result;
    }
    
    /**
     Escape string
     - parameter value: string to escape
     - returns: escaped string
     */
    public static func escape(_ value:String) -> String {
        var result = value;
        var i=0;
        while i < ENTITIES.count {
            result = result.replacingOccurrences(of: ENTITIES[i][0], with: ENTITIES[i][1]);
            i += 1;
        }
        return result;
    }
    
}
