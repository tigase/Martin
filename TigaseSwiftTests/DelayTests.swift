//
// DelayTests.swift
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

import XCTest
@testable import TigaseSwift

class DelayTests: XCTestCase {
    
    func testParsing() {
        let from = JID("test@example.com");
        var el = Element(name: "delay", attributes:["from": from.stringValue, "stamp": "2016-05-06T20:65:32Z"]);
        let delay = Delay(element: el);
        XCTAssertNotNil(delay);
        XCTAssertNotNil(delay.stamp);
        XCTAssertEqual(delay.from, from);
        
        let delay2 = Element(name: "delay", attributes:["from": from.stringValue, "stamp": "2016-05-06T20:65:32.453Z"]);
        XCTAssertNotNil(delay2);
        XCTAssertNotNil(delay2.stamp);
        XCTAssertEqual(delay2.from, from);
        XCTAssertEqual(delay.stamp!.earlierDate(delay2.stamp!), delay.stamp!);
        XCTAssertEqual(delay2.stamp!.laterDate(delay1.stamp!), delay2.stamp!);
    }
    
}