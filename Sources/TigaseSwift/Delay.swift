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
open class Delay {
    
    @available(iOS 12.0, OSX 10.14, *)
    private static let isoStampFormatter = { ()-> ISO8601DateFormatter in
        let f = ISO8601DateFormatter();
        f.formatOptions = ISO8601DateFormatter.Options(arrayLiteral: [.withColonSeparatorInTime,.withColonSeparatorInTimeZone,.withFullDate,.withFullTime,.withDashSeparatorInDate,.withTimeZone]);
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    }();

    @available(iOS 12.0, OSX 10.14, *)
    private static let isoStampWithMilisFormatter = { ()-> ISO8601DateFormatter in
        let f = ISO8601DateFormatter();
        var options = f.formatOptions;
        options.insert(ISO8601DateFormatter.Options.withFractionalSeconds);
        f.formatOptions = ISO8601DateFormatter.Options(arrayLiteral: [.withColonSeparatorInTime,.withColonSeparatorInTimeZone,.withFullDate,.withFullTime,.withDashSeparatorInDate,.withFractionalSeconds,.withTimeZone]);
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    }();

    fileprivate static let stampFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.locale = Locale(identifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    })();
    
    fileprivate static let stampWithMilisFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.locale = Locale(identifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    })();
    
    /// Holds timestamp when delay started. In most cases it is very close to time when stanza was sent.
    public let stamp:Date?;
    /// JID of entity responsible for delay
    public let from:JID?;
    
    public init(element:Element) {
        if let stampStr = element.getAttribute("stamp") {
            if #available(iOS 12.0, OSX 10.14, *) {
                stamp = Delay.isoStampWithMilisFormatter.date(from: stampStr) ?? Delay.isoStampFormatter.date(from: stampStr);
            } else {
                stamp = Delay.stampWithMilisFormatter.date(from: stampStr) ?? Delay.stampFormatter.date(from: stampStr);
            }
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
