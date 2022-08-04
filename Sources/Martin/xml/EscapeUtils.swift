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
public struct EscapeUtils {
    
    private struct Entity {
        let unescapedValue: String;
        let escapedValue: String;
        let numericReference: String;
    }
    
    private static let ENTITIES: [Entity] = [
        .init(unescapedValue: "&", escapedValue: "&amp;", numericReference:  "&#38;"),
        .init(unescapedValue: "<", escapedValue: "&lt;", numericReference: "&#60;"),
        .init(unescapedValue: ">", escapedValue: "&gt;", numericReference: "&#62;"),
        .init(unescapedValue: "\"", escapedValue: "&quot;", numericReference: "&#34;"),
        .init(unescapedValue: "'", escapedValue: "&apos;", numericReference: "&#39;")
    ]
        
    public static func unescape(_ value: String?) -> String? {
        guard let value = value else {
            return nil;
        }
        
        return unescape(value);
    }
    
    /**
     Unescape string
     - parameter value: string to unescape
     - returns: unescaped string
     */
    public static func unescape(_ value:String) -> String {
        guard value.contains("&") else {
            return value;
        }

        var result = value;
        for entity in ENTITIES {
            // this is for libxml2 as it replaces every &amp; with &#38; which in XML both replaces &
            result = result.replacingOccurrences(of: entity.numericReference, with: entity.unescapedValue);
            // this is for normal replacement (may not be needed but let's keep it for compatibility
            result = result.replacingOccurrences(of: entity.escapedValue, with: entity.unescapedValue);
        }
        
        return result;
    }
    
    public static func escape(_ value: String?) -> String? {
        guard let value = value else {
            return nil;
        }
        
        return escape(value);
    }
    
    /**
     Escape string
     - parameter value: string to escape
     - returns: escaped string
     */
    public static func escape(_ value:String) -> String {
        var result = value;
        for entity in ENTITIES {
            result = result.replacingOccurrences(of: entity.unescapedValue, with: entity.escapedValue);
        }
        return result;
    }
    
}

extension String {
    
    public func xmlEscaped() -> String {
        return EscapeUtils.escape(self);
    }
    
    public func xmlUnescaped() -> String {
        return EscapeUtils.unescape(self);
    }
    
}
