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

public class TimestampHelper {
    
    private static let isoStampFormatter = { ()-> ISO8601DateFormatter in
        let f = ISO8601DateFormatter();
        f.formatOptions = ISO8601DateFormatter.Options(arrayLiteral: [.withColonSeparatorInTime,.withColonSeparatorInTimeZone,.withFullDate,.withFullTime,.withDashSeparatorInDate,.withTimeZone]);
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    }();

    private static let isoStampWithMilisFormatter = { ()-> ISO8601DateFormatter in
        let f = ISO8601DateFormatter();
        var options = f.formatOptions;
        options.insert(ISO8601DateFormatter.Options.withFractionalSeconds);
        f.formatOptions = ISO8601DateFormatter.Options(arrayLiteral: [.withColonSeparatorInTime,.withColonSeparatorInTimeZone,.withFullDate,.withFullTime,.withDashSeparatorInDate,.withFractionalSeconds,.withTimeZone]);
        f.timeZone = TimeZone(secondsFromGMT: 0);
        return f;
    }();
    
    public static func parse(timestamp: String?) -> Date? {
        guard let stampStr = timestamp else {
            return nil;
        }
        
        return isoStampWithMilisFormatter.date(from: stampStr) ?? isoStampFormatter.date(from: stampStr);
    }
    
    public static func format(date: Date, withMilliseconds withMs: Bool = true) -> String {
        if withMs {
            return isoStampWithMilisFormatter.string(from: date);
        } else {
            return isoStampFormatter.string(from: date);
        }
    }
}
