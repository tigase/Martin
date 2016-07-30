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

/**
 Custom structure used as logging utility to log entries with timestamps
 and other additional data for easier analysis of logs.
 
 It is required to initialize this utility class before it is used
 by calling:
 ```
    Log.initialize();
 ```
 */
public struct Log {
    
    private static let dateFormatter = NSDateFormatter();
    
    /// Method to initialize this mechanism
    public static func initialize() {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS";
        
    }
    
    /**
     Methods logs items passed.
     - parameter items: items to log
     - parameter from: source of this entry
     */
    public static func log(items: Any..., from: Any? = nil) {
        #if !DISABLE_LOG
            logInternal(items, from: from)
        #endif
    }
    
    /**
     Methods logs items passed.
     - parameter items: items to log
     - parameter from: source of this entry
     */
    static func logInternal<T>(items: [T], from: Any? = nil) {
        #if !DISABLE_LOG
            let date = NSDate();
            let prefix = dateFormatter.stringFromDate(date);
            var entry = prefix + " ";
            if (from != nil) {
                entry +=  "\(from!) ";
            }
            entry += (items.map({ it in "\(it)"}).joinWithSeparator(" "));
            print(entry)
        #endif
    }
    
}

/**
 Class which is used by many TigaseSwift classes for easier logging.
 When other classes extends it, it adds a `log(items: Any..)` method
 which provides this extending class as source of this log entry.
 */
public class Logger {
    
    public init() {
        
    }
    
    /**
     Method logs entry with providing `self.dynamicType` as source
     of this entry log.
     - parameter items: items to add to log
     */
    public func log(items: Any...) {
        #if !DISABLE_LOG
            Log.logInternal(items, from: self.dynamicType)
        #endif
    }
}

/// Extension of NSObject to provide support for TigaseSwift logging feature
extension NSObject {

    /**
     Method logs entry with providing `self.dynamicType` as source
     of this entry log.
     - parameter items: items to add to log
     */
    public func log(items: Any...) {
        #if !DISABLE_LOG
            Log.logInternal(items, from: self.dynamicType)
        #endif
    }
    
}