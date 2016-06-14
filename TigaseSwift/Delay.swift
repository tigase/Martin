//
// Delay.swift
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
 Holds information about stanza delayed delivery as described in [XEP-0203: Delayed Delivery]
 
 [XEP-0203: Delayed Delivery]: http://xmpp.org/extensions/xep-0203.html
 */
public class Delay {
    
    private static let stampFormatter = ({()-> NSDateFormatter in
        var f = NSDateFormatter();
        f.locale = NSLocale(localeIdentifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        f.timeZone = NSTimeZone(forSecondsFromGMT: 0);
        return f;
    })();
    
    private static let stampWithMilisFormatter = ({()-> NSDateFormatter in
        var f = NSDateFormatter();
        f.locale = NSLocale(localeIdentifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
        f.timeZone = NSTimeZone(forSecondsFromGMT: 0);
        return f;
    })();
    
    /// Holds timestamp when delay started. In most cases it is very close to time when stanza was sent.
    public let stamp:NSDate?;
    /// JID of entity responsible for delay
    public let from:JID?;
    
    public init(element:Element) {
        if let stampStr = element.getAttribute("stamp") {
            stamp = Delay.stampFormatter.dateFromString(stampStr) ?? Delay.stampWithMilisFormatter.dateFromString(stampStr);
        } else {
            stamp = nil;
        }
        if let fromStr = element.getAttribute("from") {
            from = JID(fromStr);
        } else {
            from = nil
        }
    }
    
}