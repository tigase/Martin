//
// Log.swift
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

public struct Log {
    
    private static let dateFormatter = NSDateFormatter();
    
    public static func initialize() {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS";
        
    }
    
    public static func log(items: Any..., from: Any? = nil) {
        #if !DISABLE_LOG
            logInternal(items, from: from)
        #endif
    }
    
    static func logInternal<T>(items: [T], from: Any? = nil) {
        #if !DISABLE_LOG
            let prefix = dateFormatter.stringFromDate(NSDate());
            var entry = prefix + " ";
            if (from != nil) {
                entry +=  "\(from!) ";
            }
            entry += (items.map({ it in "\(it)"}).joinWithSeparator(" "));
            print(entry)
        #endif
    }
    
}

public class Logger {
    public func log(items: Any...) {
        #if !DISABLE_LOG
            Log.logInternal(items, from: self.dynamicType)
        #endif
    }
}

extension NSObject {

    public func log(items: Any...) {
        #if !DISABLE_LOG
            Log.logInternal(items, from: self.dynamicType)
        #endif
    }
    
}