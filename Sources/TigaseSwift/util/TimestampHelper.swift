//
// TimestampHelper.swift
//
// TigaseSwift
// Copyright (C) 2020 "Tigase, Inc." <office@tigase.com>
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

class TimestampHelper {
    
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

    private static let stampFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.locale = Locale(identifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    })();
    
    private static let stampWithMilisFormatter = ({()-> DateFormatter in
        var f = DateFormatter();
        f.locale = Locale(identifier: "en_US_POSIX");
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    })();
    
    static func parse(timestamp: String?) -> Date? {
        guard let stampStr = timestamp else {
            return nil;
        }
        
        if #available(iOS 12.0, OSX 10.14, *) {
            return isoStampWithMilisFormatter.date(from: stampStr) ?? isoStampFormatter.date(from: stampStr);
        } else {
            return stampWithMilisFormatter.date(from: stampStr) ?? stampFormatter.date(from: stampStr);
        }
    }
    
    static func format(date: Date, withMilliseconds withMs: Bool = true) -> String {
        if #available(iOS 12.0, OSX 10.14, *) {
            if withMs {
                return isoStampWithMilisFormatter.string(from: date);
            } else {
                return isoStampFormatter.string(from: date);
            }
        } else {
            if withMs {
                return stampWithMilisFormatter.string(from: date);
            } else {
                return stampFormatter.string(from: date);
            }
        }
    }
}
